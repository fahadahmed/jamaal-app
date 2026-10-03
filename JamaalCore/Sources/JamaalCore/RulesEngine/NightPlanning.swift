import Foundation
import SwiftData

/// Which flow a session runs: the full evening one, or the shortened morning one for today.
public enum PlanningMode: Sendable { case evening, morning }

/// Step 3's read model: the shape of the planned day and what's in it.
public struct PlanBuild {
    public var forDate: CalendarDate
    /// The working day, its fixed commitments and the named gaps between them.
    public var freeTime: FreeTime.Result
    /// The plan's tasks (live, due on or before the date), in the engine's order. Tasks have no manual order.
    public var tasks: [TaskItem]
    /// The day's habits, read-only: scheduled, not chosen; paused ones don't appear.
    public var habitWindows: [DueWindow]
    public var anchors: [Anchor]
    /// Important-but-not-urgent tasks (the `schedule` quadrant): this is the moment to schedule them.
    public var scheduleSuggestions: [TaskItem]
    /// Undated tasks that can be pulled in.
    public var backlogCandidates: [TaskItem]
    /// Tasks longer than the longest gap: a flag, never a block.
    public var doesNotFit: [TaskItem]
    public var shouldPickPriorities: Bool
    public var hasMultipleDoFirst: Bool
    public var missingDurations: Int
}

/// The one reschedule the load step offers.
public struct MoveSuggestion {
    public var task: TaskItem
    /// The nearest of the next seven days that stays under full, or `nil` — ask the user for a date.
    public var target: CalendarDate?
}

/// Step 4's read model.
public struct LoadCheck {
    public var level: CapacityLevel
    public var budgetMinutes: Int
    public var plannedMinutes: Int
    public var loadScore: Int
    public var state: LoadState
    /// Planned task minutes beyond the day's free time ("40 min past 19:00").
    public var overflowMinutes: Int
    /// The highest level that fits the free time. The user decides.
    public var suggestedLevel: CapacityLevel
    public var missingDurations: Int
    public var moveSuggestion: MoveSuggestion?
}

public struct ClosingSummary: Equatable, Sendable {
    public var taskCount: Int
    public var plannedMinutes: Int
    /// A plain count of distinct closed nights: not a streak.
    public var nightsPlanned: Int
}

/// Module 4: Night Planning orchestration (docs/journeys/night-planning.md). Part 1: the session
/// lifecycle, the Build and Load steps, and Close.
///
/// `review → carry → build → load → close`, or the morning's shortened `build → load → close`. A
/// session persists, so closing the app mid-flow resumes at the same step, even on another device.
public enum NightPlanning {

    // MARK: Lifecycle

    /// The steps of a session's flow.
    public static func steps(for session: NightPlanningSession) -> [PlanningStep] {
        session.isShortened ? [.build, .load, .close] : [.review, .carry, .build, .load, .close]
    }

    /// Opens (or resumes) the session for `forDate`.
    ///
    /// A session already in progress resumes where it was. A **closed** one reopens at Build so the
    /// user can adjust, and stays confirmed until it is closed again (re-closing rewrites the
    /// snapshot). A **skipped** one clears the skip and starts its flow again. Otherwise a new one
    /// starts at Review, or at Build for the shortened morning flow.
    @MainActor
    public static func open(forDate: CalendarDate, mode: PlanningMode, now: Date, context: ModelContext) throws -> NightPlanningSession {
        let existing = try context.fetch(FetchDescriptor<NightPlanningSession>())
            .filter { CalendarDate(storedDate: $0.forDate) == forDate }
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        if let session = existing {
            if session.skippedAt != nil {
                session.skippedAt = nil
                session.step = steps(for: session)[0]
            } else if session.isComplete {
                session.step = .build
            }
            return session
        }
        let session = NightPlanningSession()
        session.forDate = forDate.storedDate
        session.createdAt = now
        session.isShortened = mode == .morning
        session.step = steps(for: session)[0]
        context.insert(session)
        return session
    }

    /// Moves to the next step (passing through Carry when there is nothing to carry) and returns it;
    /// at the last step it stays.
    @discardableResult
    public static func advance(_ session: NightPlanningSession, carryHasWork: Bool) -> PlanningStep {
        let flow = steps(for: session)
        var index = (flow.firstIndex(of: session.step) ?? 0) + 1
        if index < flow.count, flow[index] == .carry, !carryHasWork { index += 1 }
        session.step = flow[min(index, flow.count - 1)]
        return session.step
    }

    /// Moves back a step (passing back over an empty Carry) and returns it; the first step stays.
    @discardableResult
    public static func back(_ session: NightPlanningSession, carryHasWork: Bool) -> PlanningStep {
        let flow = steps(for: session)
        var index = (flow.firstIndex(of: session.step) ?? 0) - 1
        if index >= 0, flow[index] == .carry, !carryHasWork { index -= 1 }
        session.step = flow[max(index, 0)]
        return session.step
    }

    /// *Skip tonight*: ends the flow with no plan. No `DayPlan` is written, and carry-forward choices
    /// already applied stay.
    public static func skip(_ session: NightPlanningSession, now: Date) {
        session.skippedAt = now
    }

    /// Whether Carry forward has anything to do: a live task due on or before the reviewed day.
    public static func carryHasWork(_ tasks: [TaskItem], reviewDate: CalendarDate) -> Bool {
        tasks.contains { task in
            !task.isCompleted && task.droppedAt == nil && task.dueDate.map { CalendarDate(storedDate: $0) <= reviewDate } == true
        }
    }

    // MARK: Build

    @MainActor
    public static func build(forDate: CalendarDate, boundary: DayBoundary, now: Date, context: ModelContext) throws -> PlanBuild {
        let plan = try computePlan(forDate: forDate, boundary: boundary, now: now, context: context)
        let live = plan.allTasks.filter { !$0.isCompleted && $0.droppedAt == nil }
        let schedule = live
            .filter { TaskPriority.quadrant($0, today: forDate) == .schedule }
            .sorted { ($0.dueDate ?? .distantFuture, $0.createdAt) < ($1.dueDate ?? .distantFuture, $1.createdAt) }
        let backlog = live.filter { $0.dueDate == nil }.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }

        return PlanBuild(
            forDate: forDate,
            freeTime: plan.freeTime,
            tasks: plan.tasks,
            habitWindows: plan.habitWindows,
            anchors: plan.anchors,
            scheduleSuggestions: schedule,
            backlogCandidates: backlog,
            doesNotFit: FreeTime.tasksThatDoNotFit(plan.tasks, longestBlockMinutes: plan.freeTime.longestBlockMinutes),
            shouldPickPriorities: TaskPriority.shouldPickPriorities(plan.tasks),
            hasMultipleDoFirst: TaskPriority.hasMultipleDoFirst(plan.tasks, today: forDate),
            missingDurations: FreeTime.missingDurations(plan.tasks)
        )
    }

    // MARK: Load

    /// Step 4's numbers for the planned day. Reading writes nothing; the level is the day's `DayPlan`
    /// capacity if one exists, else that weekday's default.
    @MainActor
    public static func loadCheck(forDate: CalendarDate, boundary: DayBoundary, now: Date, context: ModelContext) throws -> LoadCheck {
        let settings = try settingsRow(in: context)
        let plan = try computePlan(forDate: forDate, boundary: boundary, now: now, context: context)
        let level = try level(for: forDate, settings: settings, context: context)
        let budget = CapacityLoad.budgetMinutes(for: level, mediumDayMinutes: settings.mediumDayMinutes)
        let planned = plan.tasks.reduce(0) { $0 + ($1.effortMinutes ?? 0) }
        let score = CapacityLoad.loadScore(plannedMinutes: planned, budgetMinutes: budget)
        let state = LoadState(score: score)
        let overflow = FreeTime.overflowMinutes(plannedMinutes: planned, freeMinutes: plan.freeTime.freeMinutes)

        var suggestion: MoveSuggestion?
        if state.isOverloaded || overflow > 0,
           let candidate = plan.tasks.last(where: { TaskPriority.quadrant($0, today: forDate) != .doFirst }) {
            suggestion = MoveSuggestion(
                task: candidate,
                target: try nearestDayUnderFull(for: candidate, after: forDate, settings: settings, all: plan.allTasks, context: context)
            )
        }

        return LoadCheck(
            level: level, budgetMinutes: budget, plannedMinutes: planned, loadScore: score, state: state,
            overflowMinutes: overflow,
            suggestedLevel: FreeTime.suggestedCapacity(freeMinutes: plan.freeTime.freeMinutes, mediumDayMinutes: settings.mediumDayMinutes),
            missingDurations: FreeTime.missingDurations(plan.tasks),
            moveSuggestion: suggestion
        )
    }

    /// Sets the planned day's level, written **the moment it is chosen** so it survives leaving the
    /// app mid-flow (an upsert of the day's `DayPlan`).
    @MainActor
    public static func setCapacity(_ level: CapacityLevel, forDate: CalendarDate, context: ModelContext) {
        guard let raw = level.storable else { return }
        let plan = dayPlan(for: forDate, in: context) ?? insertDayPlan(for: forDate, in: context)
        plan.capacity = raw
        try? context.save()
    }

    /// Moves a task to another day while planning. This is *rescheduling*, not a deferral: no count,
    /// no record, no easing (the day under review is `reviewing`).
    @MainActor
    public static func move(_ task: TaskItem, to date: CalendarDate, reviewing: CalendarDate, now: Date, boundary: DayBoundary, context: ModelContext) throws {
        _ = try TaskDeferral.defer(task, from: reviewing, to: date, reason: .unspecified, now: now, boundary: boundary, context: context)
    }

    // MARK: Close

    /// Closes the day: locks the plan, upserting the `DayPlan` snapshot (level kept, or the weekday
    /// default if none was chosen; planned minutes, free and committed time, load score, whether it
    /// was overloaded, and when planning finished), and completes the session.
    @MainActor
    @discardableResult
    public static func close(_ session: NightPlanningSession, boundary: DayBoundary, now: Date, context: ModelContext) throws -> ClosingSummary {
        let forDate = CalendarDate(storedDate: session.forDate)
        let settings = try settingsRow(in: context)
        let plan = try computePlan(forDate: forDate, boundary: boundary, now: now, context: context)
        let existing = dayPlan(for: forDate, in: context)
        let dayPlan = existing ?? insertDayPlan(for: forDate, in: context)
        if existing == nil { dayPlan.capacityLevel = settings.defaultLevel(forISOWeekday: forDate.isoWeekday) }

        let planned = plan.tasks.reduce(0) { $0 + ($1.effortMinutes ?? 0) }
        let level = dayPlan.capacityLevel.isUnknown ? settings.defaultLevel(forISOWeekday: forDate.isoWeekday) : dayPlan.capacityLevel
        let score = CapacityLoad.loadScore(plannedMinutes: planned, budgetMinutes: CapacityLoad.budgetMinutes(for: level, mediumDayMinutes: settings.mediumDayMinutes))
        dayPlan.plannedTaskMinutes = planned
        dayPlan.freeMinutes = plan.freeTime.freeMinutes
        dayPlan.committedMinutes = plan.freeTime.committedMinutes
        dayPlan.loadScore = score
        dayPlan.wasOverloaded = LoadState(score: score).isOverloaded
        dayPlan.planningCompletedAt = now

        session.isComplete = true
        session.completedAt = now
        session.skippedAt = nil
        session.step = .close
        try context.save()

        let nights = Set(try context.fetch(FetchDescriptor<NightPlanningSession>()).filter(\.isComplete).map { CalendarDate(storedDate: $0.forDate) })
        return ClosingSummary(taskCount: plan.tasks.count, plannedMinutes: planned, nightsPlanned: nights.count)
    }

    // MARK: Helpers

    private struct Computed {
        var allTasks: [TaskItem]
        var tasks: [TaskItem]
        var anchors: [Anchor]
        var habitWindows: [DueWindow]
        var freeTime: FreeTime.Result
    }

    @MainActor
    private static func computePlan(forDate: CalendarDate, boundary: DayBoundary, now: Date, context: ModelContext) throws -> Computed {
        let settings = try settingsRow(in: context)
        let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
        let planned = TaskPriority.order(
            allTasks.filter { task in
                !task.isCompleted && task.droppedAt == nil && task.dueDate.map { CalendarDate(storedDate: $0) <= forDate } == true
            },
            today: forDate
        )
        let anchors = try context.fetch(FetchDescriptor<Anchor>())
            .filter { CalendarDate(storedDate: $0.occurrenceDate) == forDate }
            .sorted { ($0.windowStart, $0.id.uuidString) < ($1.windowStart, $1.id.uuidString) }
        let habits = try context.fetch(FetchDescriptor<Habit>())
        let due = HabitToday.dueWindows(of: habits, context: HabitContext(boundary: boundary, today: forDate))
        let isToday = boundary.logicalDate(at: now) == forDate
        let freeTime = FreeTime.compute(
            day: forDate, boundary: boundary, dayStartMinute: settings.dayStartMinute, dayEndMinute: settings.dayEndMinute,
            now: isToday ? now : nil, commitments: FreeTime.commitments(from: anchors), habitMinutes: HabitToday.remainingMinutes(due)
        )
        return Computed(allTasks: allTasks, tasks: planned, anchors: anchors, habitWindows: due, freeTime: freeTime)
    }

    @MainActor
    private static func settingsRow(in context: ModelContext) throws -> UserSettings {
        try context.fetch(FetchDescriptor<UserSettings>())
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) } ?? UserSettings()
    }

    @MainActor
    private static func dayPlan(for day: CalendarDate, in context: ModelContext) -> DayPlan? {
        ((try? context.fetch(FetchDescriptor<DayPlan>())) ?? [])
            .filter { CalendarDate(storedDate: $0.date) == day }
            .min { $0.id.uuidString < $1.id.uuidString }
    }

    @MainActor
    private static func insertDayPlan(for day: CalendarDate, in context: ModelContext) -> DayPlan {
        let plan = DayPlan()
        plan.date = day.storedDate
        context.insert(plan)
        return plan
    }

    @MainActor
    private static func level(for day: CalendarDate, settings: UserSettings, context: ModelContext) throws -> CapacityLevel {
        if let plan = dayPlan(for: day, in: context), !plan.capacityLevel.isUnknown { return plan.capacityLevel }
        return settings.defaultLevel(forISOWeekday: day.isoWeekday)
    }

    /// The nearest of the next seven days whose load, with `task` added, stays under 100%.
    @MainActor
    private static func nearestDayUnderFull(
        for task: TaskItem, after day: CalendarDate, settings: UserSettings, all: [TaskItem], context: ModelContext
    ) throws -> CalendarDate? {
        for offset in 1...7 {
            let candidate = day.addingDays(offset)
            let existing = all
                .filter { !$0.isCompleted && $0.droppedAt == nil && $0.id != task.id && $0.dueDate.map { CalendarDate(storedDate: $0) } == candidate }
                .reduce(0) { $0 + ($1.effortMinutes ?? 0) }
            let level = try level(for: candidate, settings: settings, context: context)
            let budget = CapacityLoad.budgetMinutes(for: level, mediumDayMinutes: settings.mediumDayMinutes)
            if CapacityLoad.loadScore(plannedMinutes: existing + (task.effortMinutes ?? 0), budgetMinutes: budget) < 100 { return candidate }
        }
        return nil
    }
}
