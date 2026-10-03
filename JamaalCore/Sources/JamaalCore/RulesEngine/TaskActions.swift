import Foundation
import SwiftData

public enum TaskActionError: Error, Equatable, Sendable {
    /// "This one already repeated": the next instance was touched, so the un-tick is refused.
    case alreadyRepeated
}

/// When a repeating task next falls (docs/schema/task.md, "Repeating tasks").
public enum TaskRepeat {

    /// The next occurrence strictly after `base` (callers pass `max(dueDate, completion day)`), or
    /// `nil` if the task doesn't repeat.
    ///
    /// Daily is the next day. Weekly is the next of the chosen ISO weekdays (none chosen: the due
    /// date's weekday). Monthly keeps one day of the month, clamped to short months without drifting
    /// (`repeatDayOfMonth`, or the due date's day if unset), so the 31st is Feb 28, then Mar 31.
    public static func nextOccurrence(of task: TaskItem, after base: CalendarDate) -> CalendarDate? {
        let due = task.dueDate.map { CalendarDate(storedDate: $0) } ?? base
        switch task.repeatMode {
        case .off, .unknown:
            return nil
        case .daily:
            return base.addingDays(1)
        case .weekly:
            var weekdays = Set(task.repeatWeekdays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { (1...7).contains($0) })
            if weekdays.isEmpty { weekdays = [due.isoWeekday] }
            return (1...7).map { base.addingDays($0) }.first { weekdays.contains($0.isoWeekday) }
        case .monthly:
            let dayOfMonth = task.repeatDayOfMonth > 0 ? task.repeatDayOfMonth : due.day
            var year = base.year, month = base.month
            for _ in 0..<2 {
                let candidate = clamped(year: year, month: month, day: dayOfMonth)
                if candidate > base { return candidate }
                month += 1
                if month > 12 { month = 1; year += 1 }
            }
            return clamped(year: year, month: month, day: dayOfMonth)
        }
    }

    private static func clamped(year: Int, month: Int, day: Int) -> CalendarDate {
        var d = min(day, 31)
        while d > 1 {
            if let date = CalendarDate(year: year, month: month, day: d) { return date }
            d -= 1
        }
        return CalendarDate(year: year, month: month, day: 1)!
    }
}

/// Completing, un-completing and dropping tasks, and the repeating-task bookkeeping that goes with them.
///
/// There is one live instance per series. The next is created when the live one is completed **or
/// dropped** (a drop skips only that occurrence), keyed by `(seriesID, dueDate)` so two devices
/// racing don't duplicate it.
public enum TaskActions {

    /// Completes a task at `now`. For a repeating task, creates the next instance (returned) unless
    /// one already exists. Completing an already completed or dropped task does nothing.
    @MainActor
    @discardableResult
    public static func complete(_ task: TaskItem, now: Date, boundary: DayBoundary, context: ModelContext) -> TaskItem? {
        guard !task.isCompleted, task.droppedAt == nil else { return nil }
        FocusSessions.closeLive(of: task, as: .finished, now: now)
        task.isCompleted = true
        task.completedAt = now
        return createNext(after: task, on: boundary.logicalDate(at: now), context: context, now: now)
    }

    /// Drops a task at `now` (soft delete). A repeating task's series continues: the next instance
    /// is created and returned.
    @MainActor
    @discardableResult
    public static func drop(_ task: TaskItem, now: Date, boundary: DayBoundary, context: ModelContext) -> TaskItem? {
        guard task.droppedAt == nil else { return nil }
        FocusSessions.closeLive(of: task, as: .dropped, now: now)
        task.droppedAt = now
        return createNext(after: task, on: boundary.logicalDate(at: now), context: context, now: now)
    }

    /// Ends a repeating task's series at the live instance.
    public static func stopRepeating(_ task: TaskItem) {
        task.repeatMode = .off
    }

    /// Un-ticks a completed task. If it repeats and the next instance exists, the next is removed
    /// when it is untouched (not completed, deferred, dropped, edited or timed); otherwise the
    /// un-tick is refused with `alreadyRepeated` and nothing changes.
    @MainActor
    public static func uncomplete(_ task: TaskItem, boundary: DayBoundary, context: ModelContext) throws {
        guard task.isCompleted else { return }
        if task.repeatMode != .off, let completedAt = task.completedAt {
            let completionDay = boundary.logicalDate(at: completedAt)
            let base = max(task.dueDate.map { CalendarDate(storedDate: $0) } ?? completionDay, completionDay)
            if let expected = nextDate(for: task, base: base) {
                let others = try instances(of: task, in: context).filter {
                    $0.id != task.id && $0.dueDate.map { CalendarDate(storedDate: $0) } == expected
                }
                guard others.allSatisfy({ isUntouched($0, comparedTo: task) }) else { throw TaskActionError.alreadyRepeated }
                for other in others { context.delete(other) }
            }
        }
        task.isCompleted = false
        task.completedAt = nil
    }

    // MARK: Next instance

    private static func nextDate(for task: TaskItem, base: CalendarDate) -> CalendarDate? {
        TaskRepeat.nextOccurrence(of: task, after: base)
    }

    @MainActor
    private static func createNext(after task: TaskItem, on day: CalendarDate, context: ModelContext, now: Date) -> TaskItem? {
        guard task.repeatMode != .off, task.repeatMode != .unknown else { return nil }
        let due = task.dueDate.map { CalendarDate(storedDate: $0) } ?? day
        if task.repeatMode == .monthly, task.repeatDayOfMonth == 0 { task.repeatDayOfMonth = due.day }
        if task.seriesID == nil { task.seriesID = UUID() }
        guard let next = nextDate(for: task, base: max(due, day)) else { return nil }

        // One live instance per series, deduplicated by (seriesID, dueDate).
        if let existing = try? instances(of: task, in: context),
           existing.contains(where: { $0.id != task.id && $0.dueDate.map { CalendarDate(storedDate: $0) } == next }) {
            return nil
        }

        let copy = TaskItem(title: task.title, dueDate: next.storedDate, effortMinutes: task.effortMinutes)
        copy.notes = task.notes
        copy.importance = task.importance
        copy.repeatKind = task.repeatKind
        copy.repeatWeekdays = task.repeatWeekdays
        copy.repeatDayOfMonth = task.repeatDayOfMonth
        copy.seriesID = task.seriesID
        copy.createdAt = now
        context.insert(copy)
        copy.category = task.category
        return copy
    }

    @MainActor
    private static func instances(of task: TaskItem, in context: ModelContext) throws -> [TaskItem] {
        guard let series = task.seriesID else { return [] }
        return try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.seriesID == series }))
    }

    private static func isUntouched(_ next: TaskItem, comparedTo task: TaskItem) -> Bool {
        !next.isCompleted && next.droppedAt == nil && next.deferralCount == 0
            && (next.deferrals ?? []).isEmpty && (next.sessions ?? []).isEmpty
            && next.title == task.title && next.notes == task.notes && next.effortMinutes == task.effortMinutes
            && next.importance == task.importance && next.category?.id == task.category?.id
            && next.repeatKind == task.repeatKind && next.repeatWeekdays == task.repeatWeekdays
            && next.repeatDayOfMonth == task.repeatDayOfMonth
    }
}
