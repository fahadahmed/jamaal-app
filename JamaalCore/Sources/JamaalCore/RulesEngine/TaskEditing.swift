import Foundation
import SwiftData

/// The fields the task editor changes in place: what one visit to a task can alter, kept so the visit can be undone as one group.
public struct TaskSnapshot: Equatable, Sendable {
    public var title: String
    public var effortMinutes: Int?
    public var importance: String
    public var dueDate: Date?
    public var categoryID: UUID?
    public var repeatKind: String
    public var repeatWeekdays: String
    public var repeatDayOfMonth: Int
}

/// One change made in a visit, for the undo toast ("Call the clinic back · now 30 min").
public enum TaskChange: Equatable, Sendable {
    case title(String)
    case effort(Int?)
    case matters(Importance)
    /// `nil` is Someday.
    case due(CalendarDate?)
    case category(String?)
    case repeats(RepeatKind)
}

/// Editing a task in place (docs/journeys/coming-up-and-day-review.md, "Task detail as the editor"): there is no edit mode, so each
/// field writes straight to the task; the importance and Someday rules are still `TaskRules`. Completing, deferring and dropping are
/// not edits and are not undone here.
public enum TaskEditing {

    // MARK: Setters

    /// Trims the title. An empty one is refused (`false`), so the field reverts to what it was.
    @discardableResult
    public static func setTitle(_ task: TaskItem, _ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        task.title = trimmed
        return true
    }

    /// 15 to 480 minutes; `nil` is *No estimate*.
    public static func setEffort(_ task: TaskItem, minutes: Int?) {
        task.effortMinutes = minutes.map { min(480, max(15, $0)) }
    }

    public static func setCategory(_ task: TaskItem, _ category: TaskCategory?) {
        task.category = category
    }

    /// A repeating task needs a date: one with none is dated `today`; an existing date is kept.
    public static func setRepeat(_ task: TaskItem, _ kind: RepeatKind, today: CalendarDate) {
        guard let raw = kind.storable else { return }
        task.repeatKind = raw
        if kind != .off && task.dueDate == nil { task.dueDate = today.storedDate }
    }

    /// *Move to today*: dates the task today. That is rescheduling, not a deferral: no count, no record, no easing.
    public static func moveToToday(_ task: TaskItem, today: CalendarDate) throws {
        try TaskRules.setDueDate(task, to: today)
    }

    // MARK: A visit's undo group

    public static func snapshot(_ task: TaskItem) -> TaskSnapshot {
        TaskSnapshot(
            title: task.title, effortMinutes: task.effortMinutes, importance: task.importance, dueDate: task.dueDate,
            categoryID: task.category?.id, repeatKind: task.repeatKind, repeatWeekdays: task.repeatWeekdays, repeatDayOfMonth: task.repeatDayOfMonth)
    }

    /// What changed since `snapshot`, in the order the rows are drawn (title first).
    public static func changes(from snapshot: TaskSnapshot, to task: TaskItem) -> [TaskChange] {
        var result: [TaskChange] = []
        if task.title != snapshot.title { result.append(.title(task.title)) }
        if task.effortMinutes != snapshot.effortMinutes { result.append(.effort(task.effortMinutes)) }
        if task.importance != snapshot.importance { result.append(.matters(task.importanceLevel)) }
        if task.dueDate != snapshot.dueDate { result.append(.due(task.dueDate.map { CalendarDate(storedDate: $0) })) }
        if task.category?.id != snapshot.categoryID { result.append(.category(task.category?.name)) }
        if task.repeatKind != snapshot.repeatKind || task.repeatWeekdays != snapshot.repeatWeekdays || task.repeatDayOfMonth != snapshot.repeatDayOfMonth {
            result.append(.repeats(task.repeatMode))
        }
        return result
    }

    /// Puts every field back as it was at the start of the visit. `categories` is where the category is found again.
    public static func restore(_ snapshot: TaskSnapshot, to task: TaskItem, categories: [TaskCategory]) {
        task.title = snapshot.title
        task.effortMinutes = snapshot.effortMinutes
        task.importance = snapshot.importance
        task.dueDate = snapshot.dueDate
        task.category = categories.first { $0.id == snapshot.categoryID }
        task.repeatKind = snapshot.repeatKind
        task.repeatWeekdays = snapshot.repeatWeekdays
        task.repeatDayOfMonth = snapshot.repeatDayOfMonth
    }
}
