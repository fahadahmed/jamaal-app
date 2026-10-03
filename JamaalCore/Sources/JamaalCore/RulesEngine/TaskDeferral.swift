import Foundation
import SwiftData

/// Deferral (docs/schema/task.md, "Deferral behaviour"). A task is *deferred* when it is moved to a
/// later day **after its due day has arrived**. Moving a task that is due later (pushing tomorrow's
/// task to Thursday, the overload *Move*) is **rescheduling**: no count, no record, no easing.
///
/// At most one deferral per task per logical day, whichever path gets there first (the rollover's
/// automatic one, or the user's Keep / Later / Defer); a later choice that day *refines* the record
/// instead of adding another.
public enum TaskDeferral {

    public struct Outcome: Equatable, Sendable {
        public enum Kind: Sendable { case deferred, refined, rescheduled }
        public var kind: Kind
        /// A medium or high task was eased to low on its third deferral; the companion says so.
        public var easedImportance: Bool
        public var isStale: Bool
        public var suggestsRemoval: Bool
    }

    /// The first and second deferrals are instant (to tomorrow); from the third a date picker opens.
    public static func requiresPicker(_ task: TaskItem) -> Bool { task.deferralCount >= 2 }

    /// Whether deferring from `day` would reach the picker: the deferral it makes is (or, if that day
    /// already has a record that would only be refined, already is) the third or later.
    public static func requiresPicker(_ task: TaskItem, from day: CalendarDate) -> Bool {
        let hasRecord = (task.deferrals ?? []).contains { CalendarDate(storedDate: $0.day) == day }
        return (hasRecord ? task.deferralCount : task.deferralCount + 1) >= TaskPriority.staleThreshold
    }

    /// Moves a task to `target` (`nil` is Someday).
    ///
    /// - Parameter day: the logical day being deferred *from*. It is today, except in Night Planning
    ///   after midnight, where the day under review is still yesterday.
    ///
    /// Throws, changing nothing, if a real deferral doesn't go to a later day, or if `nil` would park
    /// an important (after any easing) or repeating task.
    @MainActor
    public static func `defer`(
        _ task: TaskItem, from day: CalendarDate, to target: CalendarDate?, reason: DeferralReason,
        now: Date, boundary: DayBoundary, context: ModelContext
    ) throws -> Outcome {
        let isRepeating = task.repeatMode != .off

        if let existing = (task.deferrals ?? []).first(where: { CalendarDate(storedDate: $0.day) == day }) {
            if let target, target <= day { throw TaskRuleError.notALaterDay }
            if target == nil && (TaskPriority.isImportant(task) || isRepeating) { throw TaskRuleError.dateRequired }
            existing.reason = reason.storable ?? DeferralReason.unspecified.rawValue
            existing.deferredTo = target?.storedDate
            task.dueDate = target?.storedDate
            FocusSessions.closeLive(of: task, as: .deferred, now: now)
            return Outcome(kind: .refined, easedImportance: false, isStale: TaskPriority.isStale(task), suggestsRemoval: TaskPriority.suggestsRemoval(task))
        }

        if let due = task.dueDate, CalendarDate(storedDate: due) <= day {
            if let target, target <= day { throw TaskRuleError.notALaterDay }
            let newCount = task.deferralCount + 1
            let willEase = newCount >= TaskPriority.staleThreshold && TaskPriority.isImportant(task)
            if target == nil && ((TaskPriority.isImportant(task) && !willEase) || isRepeating) { throw TaskRuleError.dateRequired }
            let eased = record(task, day: day, deferredOn: now, to: target, reason: reason, context: context)
            FocusSessions.closeLive(of: task, as: .deferred, now: now)
            return Outcome(kind: .deferred, easedImportance: eased, isStale: TaskPriority.isStale(task), suggestsRemoval: TaskPriority.suggestsRemoval(task))
        }

        // Not due yet (or never dated): rescheduling.
        if target == nil && (TaskPriority.isImportant(task) || isRepeating) { throw TaskRuleError.dateRequired }
        task.dueDate = target?.storedDate
        return Outcome(kind: .rescheduled, easedImportance: false, isStale: TaskPriority.isStale(task), suggestsRemoval: TaskPriority.suggestsRemoval(task))
    }

    /// Writes one deferral: the record for `day`, the count, the easing of medium and high on the
    /// third, and the new date. Shared with the rollover's automatic deferral. Returns whether
    /// importance was eased.
    @MainActor
    @discardableResult
    static func record(
        _ task: TaskItem, day: CalendarDate, deferredOn: Date, to target: CalendarDate?,
        reason: DeferralReason, context: ModelContext
    ) -> Bool {
        let deferral = DeferralRecord()
        deferral.day = day.storedDate
        deferral.deferredOn = deferredOn
        deferral.deferredTo = target?.storedDate
        deferral.reason = reason.storable ?? DeferralReason.unspecified.rawValue
        context.insert(deferral)
        deferral.task = task

        task.deferralCount += 1
        var eased = false
        if task.deferralCount >= TaskPriority.staleThreshold, TaskPriority.isImportant(task) {
            task.importanceLevel = .low
            eased = true
        }
        task.dueDate = target?.storedDate
        return eased
    }
}
