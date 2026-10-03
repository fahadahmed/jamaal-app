import Foundation
import SwiftData

// MARK: Review

/// A habit window in the review: how the day went, honestly (a counted habit shows "2 of 3").
public struct HabitReview {
    public var habit: Habit
    public var window: HabitTimeWindow
    public var state: DensityState
    public var amount: Int
    public var target: Int
}

/// An Anchor in the review, read so far: one still open at review time reads as open, not missed.
public struct AnchorReview {
    public var anchor: Anchor
    public var status: AttendanceStatus
    public var windowState: AnchorWindowState
}

/// Time actually spent on a task against its estimate.
public struct TimeSpent {
    public var task: TaskItem
    public var actualMinutes: Int
    public var estimateMinutes: Int?
}

/// Step 1's read model: the day in plain counts, no praise or blame.
public struct DayReview {
    public var reviewDate: CalendarDate
    public var completedTasks: [TaskItem]
    public var leftTasks: [TaskItem]
    public var habits: [HabitReview]
    public var anchors: [AnchorReview]
    public var timeSpent: [TimeSpent]

    public var doneCount: Int { completedTasks.count }
    public var leftCount: Int { leftTasks.count }
    public var habitsDue: Int { habits.count }
    public var habitsDone: Int { habits.filter { $0.state == .complete }.count }
    public var totalActualMinutes: Int { timeSpent.reduce(0) { $0 + $1.actualMinutes } }
}

// MARK: Carry forward

public enum CarryChoice {
    /// To the planned day, as a deferral.
    case keep
    /// To a chosen day (or Someday for a low task), with a reason.
    case later(CalendarDate?, DeferralReason)
    case drop
}

public enum CarryError: Error, Equatable, Sendable {
    /// From the third deferral, Keep opens the picker instead: use `.later`.
    case pickerRequired
    /// Choices are undoable only until the day is closed.
    case dayClosed
}

public enum CarryState: Equatable, Sendable {
    case pending
    /// Already moved: to a day, or `nil` for Someday.
    case moved(to: CalendarDate?)
    case dropped
}

public struct CarryItem {
    public var task: TaskItem
    public var state: CarryState
}

/// What a carry choice did, and what is needed to undo it.
public struct CarryResult {
    public var outcome: TaskDeferral.Outcome?
    /// A repeating task's next instance, created when it was dropped.
    public var createdNext: TaskItem?

    fileprivate var task: TaskItem
    fileprivate var dueDate: Date?
    fileprivate var deferralCount: Int
    fileprivate var importance: String
    fileprivate var droppedAt: Date?
    fileprivate var createdRecords: [DeferralRecord]
    fileprivate var refinedRecords: [(record: DeferralRecord, reason: String, deferredTo: Date?)]
}

extension NightPlanning {

    // MARK: Review

    /// The day under review. At 00:30 after a midnight rollover that is still yesterday, so a task the
    /// rollover has already moved still counts as left for it.
    @MainActor
    public static func review(reviewDate: CalendarDate, boundary: DayBoundary, now: Date, context: ModelContext) throws -> DayReview {
        func logical(_ instant: Date) -> CalendarDate { boundary.logicalDate(at: instant) }
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())

        let completed = tasks
            .filter { $0.isCompleted && $0.completedAt.map(logical) == reviewDate }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        let left = tasks.filter { task in
            guard !task.isCompleted, task.droppedAt == nil else { return false }
            let due = task.dueDate.map { CalendarDate(storedDate: $0) <= reviewDate } ?? false
            return due || (task.deferrals ?? []).contains { CalendarDate(storedDate: $0.day) == reviewDate }
        }.sorted { ($0.dueDate ?? .distantFuture, $0.createdAt) < ($1.dueDate ?? .distantFuture, $1.createdAt) }

        // The reviewed day is over for habit purposes: resolve it as if it were yesterday.
        let habitContext = HabitContext(
            boundary: boundary, today: reviewDate.addingDays(1),
            engagedDays: try Engagement.engagedDays(in: context, boundary: boundary)
        )
        var habitReviews: [HabitReview] = []
        for habit in try context.fetch(FetchDescriptor<Habit>()) where HabitSchedule.isActive(habit, on: reviewDate, context: habitContext) {
            for window in habit.windows ?? [] {
                let state = HabitDensity.state(of: window, on: reviewDate, context: habitContext)
                let due = habit.targetPerWeek > 0 ? state != .empty : HabitSchedule.isScheduled(habit, on: reviewDate) || state != .empty
                guard due else { continue }
                let entry = (window.entries ?? []).filter { CalendarDate(storedDate: $0.date) == reviewDate }.max { $0.amount < $1.amount }
                habitReviews.append(HabitReview(habit: habit, window: window, state: state, amount: entry?.amount ?? 0, target: entry?.target ?? window.target))
            }
        }

        let anchors = try context.fetch(FetchDescriptor<Anchor>())
            .filter { CalendarDate(storedDate: $0.occurrenceDate) == reviewDate }
            .sorted { ($0.windowStart, $0.id.uuidString) < ($1.windowStart, $1.id.uuidString) }
            .map { AnchorReview(anchor: $0, status: AnchorAttendance.displayStatus(of: $0, at: now), windowState: AnchorAttendance.windowState(of: $0, at: now)) }

        var seconds: [UUID: (task: TaskItem, seconds: Int, estimate: Int?)] = [:]
        for session in try context.fetch(FetchDescriptor<WorkSession>()) {
            guard let task = session.task, CalendarDate(storedDate: session.day) == reviewDate,
                  session.outcome != SessionOutcome.running.rawValue, session.outcome != SessionOutcome.manual.rawValue else { continue }
            let known = seconds[task.id]
            seconds[task.id] = (task, (known?.seconds ?? 0) + session.actualSeconds, session.estimateMinutes ?? known?.estimate ?? task.effortMinutes)
        }
        let timeSpent = seconds.values
            .map { TimeSpent(task: $0.task, actualMinutes: Int((Double($0.seconds) / 60).rounded()), estimateMinutes: $0.estimate) }
            .sorted { ($0.task.createdAt, $0.task.id.uuidString) < ($1.task.createdAt, $1.task.id.uuidString) }

        return DayReview(reviewDate: reviewDate, completedTasks: completed, leftTasks: left, habits: habitReviews, anchors: anchors, timeSpent: timeSpent)
    }

    // MARK: Carry forward

    /// What the Carry step lists, each with the choice made so far: live tasks due on or before the
    /// reviewed day (or already moved from it), and ones dropped that day, so a choice can be changed.
    public static func carryItems(tasks: [TaskItem], reviewing: CalendarDate, boundary: DayBoundary) -> [CarryItem] {
        var items: [CarryItem] = []
        for task in tasks where !task.isCompleted {
            if let dropped = task.droppedAt {
                if boundary.logicalDate(at: dropped) == reviewing { items.append(CarryItem(task: task, state: .dropped)) }
                continue
            }
            if let record = (task.deferrals ?? []).first(where: { CalendarDate(storedDate: $0.day) == reviewing }) {
                items.append(CarryItem(task: task, state: .moved(to: record.deferredTo.map { CalendarDate(storedDate: $0) })))
            } else if task.dueDate.map({ CalendarDate(storedDate: $0) <= reviewing }) == true {
                items.append(CarryItem(task: task, state: .pending))
            }
        }
        return items.sorted { ($0.task.dueDate ?? .distantFuture, $0.task.createdAt) < ($1.task.dueDate ?? .distantFuture, $1.task.createdAt) }
    }

    /// Whether *Keep* has to open the picker instead of acting: from the third deferral onwards.
    public static func keepNeedsPicker(_ task: TaskItem, reviewing: CalendarDate) -> Bool {
        TaskDeferral.requiresPicker(task, from: reviewing)
    }

    /// Applies a carry choice at once (the deferral rules apply: instant for the first two, the third
    /// eases medium and high to low, a choice on a day that already has a record refines it).
    /// Undoable until the day is closed.
    @MainActor
    @discardableResult
    public static func carry(
        _ task: TaskItem, _ choice: CarryChoice, reviewing: CalendarDate, forDate: CalendarDate,
        now: Date, boundary: DayBoundary, context: ModelContext
    ) throws -> CarryResult {
        if case .keep = choice, keepNeedsPicker(task, reviewing: reviewing) { throw CarryError.pickerRequired }

        let recordsBefore = task.deferrals ?? []
        let beforeIDs = Set(recordsBefore.map(\.id))
        let seriesBefore = Set(((try? seriesInstances(of: task, in: context)) ?? []).map(\.id))
        var result = CarryResult(
            outcome: nil, createdNext: nil, task: task, dueDate: task.dueDate, deferralCount: task.deferralCount,
            importance: task.importance, droppedAt: task.droppedAt, createdRecords: [],
            refinedRecords: recordsBefore
                .filter { CalendarDate(storedDate: $0.day) == reviewing }
                .map { ($0, $0.reason, $0.deferredTo) }
        )

        switch choice {
        case .keep:
            result.outcome = try TaskDeferral.defer(task, from: reviewing, to: forDate, reason: .unspecified, now: now, boundary: boundary, context: context)
        case .later(let date, let reason):
            result.outcome = try TaskDeferral.defer(task, from: reviewing, to: date, reason: reason, now: now, boundary: boundary, context: context)
        case .drop:
            result.createdNext = TaskActions.drop(task, now: now, boundary: boundary, context: context)
        }
        result.createdRecords = (task.deferrals ?? []).filter { !beforeIDs.contains($0.id) }
        if result.createdNext == nil, let next = ((try? seriesInstances(of: task, in: context)) ?? []).first(where: { !seriesBefore.contains($0.id) }) {
            result.createdNext = next
        }
        return result
    }

    /// Undoes a carry choice, restoring the task, its deferral record and importance exactly (and
    /// removing a repeating task's next instance). Only until the day is closed.
    @MainActor
    public static func undoCarry(_ result: CarryResult, session: NightPlanningSession, context: ModelContext) throws {
        guard !session.isComplete else { throw CarryError.dayClosed }
        let task = result.task
        for record in result.createdRecords { context.delete(record) }
        for (record, reason, deferredTo) in result.refinedRecords {
            record.reason = reason
            record.deferredTo = deferredTo
        }
        if let next = result.createdNext { context.delete(next) }
        task.dueDate = result.dueDate
        task.deferralCount = result.deferralCount
        task.importance = result.importance
        task.droppedAt = result.droppedAt
        try context.save()
    }

    @MainActor
    private static func seriesInstances(of task: TaskItem, in context: ModelContext) throws -> [TaskItem] {
        guard let series = task.seriesID else { return [] }
        return try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.seriesID == series }))
    }
}
