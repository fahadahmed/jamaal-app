import Foundation
import SwiftData

/// What a rollover catch-up did.
public struct RolloverReport: Equatable, Sendable {
    /// The ended days processed, oldest first.
    public var processedDays: [CalendarDate] = []
    /// The most recent ended day now processed: store it (per device) for the next catch-up.
    public var lastProcessed: CalendarDate
    /// Automatic deferrals recorded.
    public var deferrals = 0
    /// `DayPlan`s created for days that had activity but no plan.
    public var dayPlansCreated = 0
    /// Running timers closed at a boundary.
    public var closedSessions = 0
    /// Unfinished planning sessions ended as skipped.
    public var endedPlanningSessions = 0
}

/// The lazy, idempotent day rollover (docs/architecture/rules-engine.md, "The day boundary").
///
/// The engine can't rely on running at midnight, so on launch, foreground and when synced data
/// arrives it processes every logical day that has ended since it last ran, oldest first. For
/// each ended day *D*:
///
/// 1. **Auto-defer** each live, dated task due on or before *D* that wasn't already deferred that
///    day (one deferral per task per day; the third eases medium and high importance to low).
/// 2. **Create and finalise `DayPlan(D)`** from the day *as lived*: load, completed effort and
///    completion rate. The plan is created for a day with activity; days with none get no row.
/// 3. **Close running timers** at the boundary instant — never "now" — so a device that slept
///    through midnight invents no phantom hours.
/// 4. **End an unfinished planning session** for *D* as skipped.
///
/// Every step is keyed so repeating it, or two devices racing it, changes nothing. The day's
/// load is computed before the auto-deferral re-dates tasks, and from deferral records
/// afterwards, so a second pass writes the same numbers. Free time (`freeMinutes`,
/// `committedMinutes`) is a separate slice and is left untouched here.
public enum Rollover {

    @MainActor
    public static func catchUp(
        in context: ModelContext,
        boundary: DayBoundary,
        lastProcessed: CalendarDate?,
        now: Date
    ) throws -> RolloverReport {
        // A first run has no history to catch up on: start from yesterday.
        let last = lastProcessed ?? boundary.logicalDate(at: now).addingDays(-1)
        var report = RolloverReport(lastProcessed: last)
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) } ?? UserSettings()

        for day in boundary.endedDays(after: last, at: now) {
            try process(day, boundary: boundary, settings: settings, context: context, report: &report)
            report.processedDays.append(day)
            report.lastProcessed = day
        }
        return report
    }

    // MARK: One ended day

    @MainActor
    private static func process(
        _ day: CalendarDate,
        boundary: DayBoundary,
        settings: UserSettings,
        context: ModelContext,
        report: inout RolloverReport
    ) throws {
        let nextDay = day.addingDays(1)
        let boundaryInstant = boundary.startInstant(of: nextDay)
        func logical(_ instant: Date) -> CalendarDate { boundary.logicalDate(at: instant) }
        func calendar(_ stored: Date) -> CalendarDate { CalendarDate(storedDate: stored) }

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())

        // The day as lived, read before the auto-deferral re-dates anything.
        let completedToday = tasks.filter { $0.isCompleted && $0.completedAt.map(logical) == day }
        let planned = tasks.filter { counts($0, on: day, logical: logical, calendar: calendar) }
        let plannedMinutes = planned.reduce(0) { $0 + minutes($1, completedToday: $1.isCompleted && $1.completedAt.map(logical) == day) }
        let completedMinutes = completedToday.reduce(0) { $0 + minutes($1, completedToday: true) }

        let activity = try hasActivity(on: day, boundary: boundary, completedToday: completedToday, context: context)

        // 1. Auto-defer.
        for task in tasks where !task.isCompleted && task.droppedAt == nil {
            guard let due = task.dueDate, calendar(due) <= day else { continue }
            if (task.deferrals ?? []).contains(where: { calendar($0.day) == day }) { continue }
            let record = DeferralRecord()
            record.day = day.storedDate
            record.deferredOn = boundaryInstant
            record.deferredTo = nextDay.storedDate
            record.reason = DeferralReason.unspecified.rawValue
            context.insert(record)
            record.task = task
            task.deferralCount += 1
            if task.deferralCount >= 3, task.importanceLevel == .medium || task.importanceLevel == .high {
                task.importanceLevel = .low
            }
            task.dueDate = nextDay.storedDate
            report.deferrals += 1
        }

        // 2. The day's record.
        let existing = try context.fetch(FetchDescriptor<DayPlan>())
            .filter { calendar($0.date) == day }
            .min { $0.id.uuidString < $1.id.uuidString }
        let dayPlan: DayPlan
        if let existing {
            dayPlan = existing
        } else if activity {
            dayPlan = DayPlan()
            dayPlan.date = day.storedDate
            dayPlan.capacityLevel = settings.defaultLevel(forISOWeekday: day.isoWeekday)
            context.insert(dayPlan)
            report.dayPlansCreated += 1
        } else {
            dayPlan = DayPlan()   // not inserted; nothing to write
            try closeSessionsAndEndPlanning(day, boundaryInstant, calendar, context, &report)
            try context.save()
            return
        }

        let budget = CapacityLoad.budgetMinutes(for: dayPlan.capacityLevel, mediumDayMinutes: settings.mediumDayMinutes)
        let score = CapacityLoad.loadScore(plannedMinutes: plannedMinutes, budgetMinutes: budget)
        dayPlan.plannedTaskMinutes = plannedMinutes
        dayPlan.loadScore = score
        dayPlan.wasOverloaded = LoadState(score: score).isOverloaded
        dayPlan.completedEffortMinutes = completedMinutes

        let completedIDs = Set(completedToday.map(\.id))
        let deferredIDs = Set(tasks.filter { task in
            !completedIDs.contains(task.id) && (task.deferrals ?? []).contains { calendar($0.day) == day }
        }.map(\.id))
        let droppedIDs = Set(tasks.filter { task in
            !completedIDs.contains(task.id) && !deferredIDs.contains(task.id) && task.droppedAt.map(logical) == day
        }.map(\.id))
        let denominator = completedIDs.count + deferredIDs.count + droppedIDs.count
        dayPlan.completionRate = denominator == 0 ? 0 : Double(completedIDs.count) / Double(denominator)

        // 3 and 4.
        try closeSessionsAndEndPlanning(day, boundaryInstant, calendar, context, &report)
        try context.save()
    }

    // MARK: Pieces

    /// Whether a task was part of day *D*'s load: completed on *D*, or live on *D* — due on or
    /// before it, or deferred away from it — and not completed or dropped before the day ended.
    private static func counts(
        _ task: TaskItem, on day: CalendarDate,
        logical: (Date) -> CalendarDate, calendar: (Date) -> CalendarDate
    ) -> Bool {
        if task.isCompleted {
            guard let completedAt = task.completedAt else { return false }
            let completedDay = logical(completedAt)
            if completedDay == day { return true }
            if completedDay < day { return false }
        }
        if let droppedAt = task.droppedAt, logical(droppedAt) <= day { return false }
        if let due = task.dueDate, calendar(due) <= day { return true }
        return (task.deferrals ?? []).contains { calendar($0.day) == day }
    }

    /// A completed-on-the-day task counts its actual focus time where it has any, else its
    /// estimate; everything else counts its estimate. No duration counts as zero.
    private static func minutes(_ task: TaskItem, completedToday: Bool) -> Int {
        if completedToday {
            let seconds = (task.sessions ?? [])
                .filter { $0.outcome != SessionOutcome.running.rawValue }
                .reduce(0) { $0 + $1.actualSeconds }
            if seconds > 0 { return Int((Double(seconds) / 60).rounded()) }
        }
        return task.effortMinutes ?? 0
    }

    /// Activity that earns a day a record: a task completed, a timer session, an Anchor decided,
    /// a habit logged (`amount > 0`; un-ticking is not activity), or the evening review of the
    /// day (a planning session for the next day, closed or skipped).
    @MainActor
    private static func hasActivity(
        on day: CalendarDate, boundary: DayBoundary, completedToday: [TaskItem], context: ModelContext
    ) throws -> Bool {
        if !completedToday.isEmpty { return true }
        if try context.fetch(FetchDescriptor<WorkSession>()).contains(where: { CalendarDate(storedDate: $0.day) == day }) { return true }
        if try context.fetch(FetchDescriptor<Anchor>()).contains(where: {
            $0.status != .pending && $0.resolvedAt.map(boundary.logicalDate(at:)) == day
        }) { return true }
        if try context.fetch(FetchDescriptor<HabitEntry>()).contains(where: {
            $0.amount > 0 && CalendarDate(storedDate: $0.date) == day
        }) { return true }
        let next = day.addingDays(1)
        return try context.fetch(FetchDescriptor<NightPlanningSession>()).contains {
            CalendarDate(storedDate: $0.forDate) == next && ($0.isComplete || $0.skippedAt != nil)
        }
    }

    @MainActor
    private static func closeSessionsAndEndPlanning(
        _ day: CalendarDate, _ boundaryInstant: Date, _ calendar: (Date) -> CalendarDate,
        _ context: ModelContext, _ report: inout RolloverReport
    ) throws {
        // 3. Running timers that started before the boundary close at it.
        for session in try context.fetch(FetchDescriptor<WorkSession>())
        where session.outcome == SessionOutcome.running.rawValue && session.endedAt == nil && session.startedAt < boundaryInstant {
            if let pausedAt = session.pausedAt {
                session.pausedSeconds += max(0, Int(boundaryInstant.timeIntervalSince(pausedAt)))
                session.pausedAt = nil
            }
            session.actualSeconds = max(0, Int(boundaryInstant.timeIntervalSince(session.startedAt)) - session.pausedSeconds)
            session.endedAt = boundaryInstant
            session.outcome = SessionOutcome.autoClosed.rawValue
            report.closedSessions += 1
        }
        // 4. A plan for a day that has now ended, still unfinished, ends as skipped.
        for planning in try context.fetch(FetchDescriptor<NightPlanningSession>())
        where !planning.isComplete && planning.skippedAt == nil && calendar(planning.forDate) <= day {
            planning.skippedAt = boundaryInstant
            report.endedPlanningSessions += 1
        }
    }
}
