import Foundation

public enum TaskRuleError: Error, Equatable, Sendable {
    /// An important or repeating task can't be parked as Someday or lose its date.
    case dateRequired
    /// A real deferral has to go to a later day.
    case notALaterDay
}

/// The importance rules (docs/schema/task.md, "Importance rules"): medium and high need a due date
/// and never Someday. SwiftData can't express the invariant, so the engine enforces it.
public enum TaskRules {

    /// Sets the importance. Raising it to medium or high on an undated task fills in
    /// `defaultDueDate` (the day being planned); an existing date is kept, and lowering never clears one.
    public static func setImportance(_ task: TaskItem, to level: Importance, defaultDueDate: CalendarDate) {
        guard let raw = level.storable else { return }
        task.importance = raw
        if (level == .medium || level == .high) && task.dueDate == nil {
            task.dueDate = defaultDueDate.storedDate
        }
    }

    /// Sets the due date. `nil` is Someday, which an important or repeating task can't have.
    public static func setDueDate(_ task: TaskItem, to date: CalendarDate?) throws {
        if date == nil && (TaskPriority.isImportant(task) || task.repeatMode != .off) { throw TaskRuleError.dateRequired }
        task.dueDate = date?.storedDate
    }

    /// Repairs a broken invariant (a race between two devices can leave an important or repeating
    /// task undated) by dating it today, keeping its importance. Returns `true` if it changed anything.
    @discardableResult
    public static func normalise(_ task: TaskItem, today: CalendarDate) -> Bool {
        guard task.dueDate == nil, TaskPriority.isImportant(task) || task.repeatMode != .off else { return false }
        task.dueDate = today.storedDate
        return true
    }
}

public enum QuickDateKind: String, Sendable {
    case today, tomorrow, laterThisWeek, nextWeek, someday
}

public struct QuickDate: Equatable, Sendable {
    public var kind: QuickDateKind
    /// `nil` for Someday.
    public var date: CalendarDate?
}

/// The quick dates of the schedule row and the defer picker (docs/schema/task.md, "Quick dates").
public enum QuickDates {

    /// - Parameter firstWeekday: the calendar's first weekday as an ISO weekday (Monday = 1 … Sunday = 7).
    ///
    /// *Later this week* is three days from now, offered only while that is still in the current week;
    /// *Next week* is the first day of next week; *Someday* is hidden for medium and high importance
    /// and for repeating tasks.
    public static func options(today: CalendarDate, firstWeekday: Int, importance: Importance, repeating: Bool) -> [QuickDate] {
        let weekStart = today.addingDays(-((today.isoWeekday - firstWeekday + 7) % 7))
        let nextWeek = weekStart.addingDays(7)
        var result = [QuickDate(kind: .today, date: today), QuickDate(kind: .tomorrow, date: today.addingDays(1))]
        let later = today.addingDays(3)
        if later < nextWeek { result.append(QuickDate(kind: .laterThisWeek, date: later)) }
        result.append(QuickDate(kind: .nextWeek, date: nextWeek))
        if importance != .medium && importance != .high && !repeating {
            result.append(QuickDate(kind: .someday, date: nil))
        }
        return result
    }
}
