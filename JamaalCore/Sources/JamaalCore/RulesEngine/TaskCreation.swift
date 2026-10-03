import Foundation
import SwiftData

public enum TaskCreationError: Error, Equatable, Sendable {
    case emptyTitle
    /// An important or repeating task can't be Someday (docs/schema/task.md, "Importance rules").
    case dateRequired
}

/// What the add sheet collects. `effortMinutes` starts at 30, the preselected chip.
public struct TaskDraft {
    public var title: String
    public var effortMinutes: Int? = 30
    public var importance: Importance = .low
    public var dueDate: CalendarDate?
    public var category: TaskCategory?
    public var repeatKind: RepeatKind = .off
    /// ISO weekdays (Monday = 1) for a weekly repeat; empty means the due date's weekday.
    public var repeatWeekdays: [Int] = []

    public init(title: String = "") { self.title = title }
}

/// "Day is full · offer tomorrow": adding this task would tip the day over its budget. Never blocks.
public struct DayFullCheck: Equatable, Sendable {
    public var plannedMinutes: Int
    public var budgetMinutes: Int
    /// The nearest of the next seven days with room for the task, or `nil` if none has.
    public var suggestion: CalendarDate?

    public init(plannedMinutes: Int, budgetMinutes: Int, suggestion: CalendarDate?) {
        self.plannedMinutes = plannedMinutes
        self.budgetMinutes = budgetMinutes
        self.suggestion = suggestion
    }
}

/// Capturing a task (journeys F03).
public enum TaskCreation {

    /// Validates the draft and inserts the task. Nothing is written when it is refused. A repeating task's
    /// `seriesID` is assigned by the engine when it is first completed, as it already is.
    @MainActor
    @discardableResult
    public static func create(_ draft: TaskDraft, in context: ModelContext, now: Date, timeZone: TimeZone = .current) throws -> TaskItem {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw TaskCreationError.emptyTitle }
        let needsDate = draft.importance == .medium || draft.importance == .high || draft.repeatKind != .off
        guard draft.dueDate != nil || !needsDate else { throw TaskCreationError.dateRequired }

        let task = TaskItem(title: title, dueDate: draft.dueDate?.storedDate, effortMinutes: draft.effortMinutes)
        task.importanceLevel = draft.importance
        task.repeatMode = draft.repeatKind
        if draft.repeatKind == .weekly {
            task.repeatWeekdays = Set(draft.repeatWeekdays.filter { (1...7).contains($0) }).sorted().map(String.init).joined(separator: ",")
        }
        context.insert(task)
        task.category = draft.category
        return task
    }

    /// Whether adding `minutes` to `day` tips it over that day's budget. Today counts what is already done too
    /// (the meter's own figure); another day counts the live tasks due on it. A task with no estimate, no date or
    /// a past date is never checked. "Room" means the task still fits within the budget.
    @MainActor
    public static func dayFullCheck(
        adding minutes: Int?, on day: CalendarDate?, in context: ModelContext, now: Date, timeZone: TimeZone = .current
    ) throws -> DayFullCheck? {
        guard let minutes, minutes > 0, let day else { return nil }
        let today = TodayDay.boundary(in: context, timeZone: timeZone).logicalDate(at: now)
        guard day >= today else { return nil }

        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first ?? UserSettings()
        func budget(_ d: CalendarDate) throws -> Int {
            CapacityLoad.budgetMinutes(for: try TodayDay.level(on: d, in: context), mediumDayMinutes: settings.mediumDayMinutes)
        }
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        func planned(_ d: CalendarDate) throws -> Int {
            if d == today { return try TodayDay.overview(in: context, now: now, timeZone: timeZone).plannedMinutes }
            return tasks.filter { !$0.isCompleted && $0.droppedAt == nil && $0.dueDate.map(CalendarDate.init(storedDate:)) == d }
                .reduce(0) { $0 + ($1.effortMinutes ?? 0) }
        }

        let planned0 = try planned(day), budget0 = try budget(day)
        guard planned0 + minutes > budget0 else { return nil }
        var suggestion: CalendarDate?
        for offset in 1...7 {
            let candidate = day.addingDays(offset)
            if try planned(candidate) + minutes <= budget(candidate) { suggestion = candidate; break }
        }
        return DayFullCheck(plannedMinutes: planned0, budgetMinutes: budget0, suggestion: suggestion)
    }
}
