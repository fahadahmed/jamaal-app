import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Repeating tasks and completing, un-completing and dropping (docs/schema/task.md, "Repeating
/// tasks"). One live instance per series; the next is the next occurrence strictly after
/// `max(dueDate, completion day)`.
@MainActor
struct TaskActionsTests {

    // October 2026: the 1st is a Thursday; Fri 2, 9, 16, 23, 30; Sun 4, 11, 18, 25.

    private func repeating(_ w: TaskWorld, _ title: String = "Timesheet", due: Int, kind: RepeatKind, weekdays: String = "") -> TaskItem {
        let t = w.task(title, due: due)
        t.repeatMode = kind
        t.repeatWeekdays = weekdays
        return t
    }

    private func series(_ w: TaskWorld) throws -> [TaskItem] {
        try w.context.fetch(FetchDescriptor<TaskItem>()).sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    // MARK: The next occurrence

    @Test(arguments: [
        (RepeatKind.daily, "", 15, 15, 16),            // kind, weekdays, due, base, expected next
        (.daily, "", 15, 20, 21),
        (.weekly, "5", 9, 11, 16),                      // Friday task finished on Sunday: next Friday, not the one passed
        (.weekly, "5", 9, 9, 16),                       // strictly after, even on the day itself
        (.weekly, "1,3", 12, 12, 14),                   // Mon and Wed: after Monday is Wednesday
        (.weekly, "1,3", 14, 14, 19),                   // after Wednesday is next Monday
        (.weekly, "", 15, 15, 22),                      // no days: the same weekday as the due date
    ])
    func nextOccurrenceFollowsTheRepeatKind(kind: RepeatKind, weekdays: String, due: Int, base: Int, expected: Int) throws {
        let w = try TaskWorld()
        let t = repeating(w, due: due, kind: kind, weekdays: weekdays)
        #expect(TaskRepeat.nextOccurrence(of: t, after: w.d(base)) == w.d(expected))
    }

    @Test func monthlyKeepsItsDayOfMonthClampedToTheMonthEndWithoutDrifting() throws {
        let w = try TaskWorld()
        func date(_ y: Int, _ m: Int, _ d: Int) -> CalendarDate { CalendarDate(year: y, month: m, day: d)! }
        let t = TaskItem(title: "Rent", dueDate: date(2027, 1, 31).storedDate)
        t.repeatMode = .monthly
        t.repeatDayOfMonth = 31
        #expect(TaskRepeat.nextOccurrence(of: t, after: date(2027, 1, 31)) == date(2027, 2, 28))
        #expect(TaskRepeat.nextOccurrence(of: t, after: date(2027, 2, 28)) == date(2027, 3, 31))       // back to the 31st
        #expect(TaskRepeat.nextOccurrence(of: t, after: date(2027, 3, 31)) == date(2027, 4, 30))
        #expect(TaskRepeat.nextOccurrence(of: t, after: date(2028, 1, 31)) == date(2028, 2, 29))       // leap year
        _ = w
    }

    @Test func monthlyWithNoStoredDayUsesTheDueDatesDay() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 15, kind: .monthly)
        #expect(TaskRepeat.nextOccurrence(of: t, after: w.d(15)) == CalendarDate(year: 2026, month: 11, day: 15))
        #expect(TaskRepeat.nextOccurrence(of: t, after: w.d(10)) == w.d(15))                           // still ahead this month
        let late = CalendarDate(year: 2026, month: 11, day: 20)!
        #expect(TaskRepeat.nextOccurrence(of: t, after: late) == CalendarDate(year: 2026, month: 12, day: 15))
    }

    @Test func aTaskThatDoesNotRepeatHasNoNextOccurrence() throws {
        let w = try TaskWorld()
        #expect(TaskRepeat.nextOccurrence(of: w.task("One-off", due: 15), after: w.d(15)) == nil)
    }

    // MARK: Complete

    @Test func completingAOneOffTaskJustCompletesIt() throws {
        let w = try TaskWorld()
        let t = w.task("Call", due: 15)
        let next = TaskActions.complete(t, now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(t.isCompleted)
        #expect(t.completedAt == w.at(15, 10))
        #expect(next == nil)
        #expect(try series(w).count == 1)
    }

    @Test func completingARepeatingTaskCreatesTheNextInstanceWithTheRightFieldsReset() throws {
        let w = try TaskWorld()
        let category = TaskCategory(name: "Work"); w.context.insert(category)
        let t = repeating(w, due: 9, kind: .weekly, weekdays: "5")
        t.notes = "- [ ] attach receipts"
        t.effortMinutes = 20
        t.importanceLevel = .medium
        t.category = category
        t.deferralCount = 2                                          // slipped before being done
        let deferral = DeferralRecord(); w.context.insert(deferral); deferral.task = t

        let next = try #require(TaskActions.complete(t, now: w.at(11, 10), boundary: w.boundary, context: w.context))   // finished on Sunday
        #expect(next.dueDate == w.d(16).storedDate)
        #expect(next.title == "Timesheet")
        #expect(next.notes == "- [ ] attach receipts")
        #expect(next.effortMinutes == 20)
        #expect(next.importanceLevel == .medium)
        #expect(next.category?.id == category.id)
        #expect(next.repeatMode == .weekly)
        #expect(next.repeatWeekdays == "5")
        #expect(next.seriesID != nil)
        #expect(next.seriesID == t.seriesID)                         // the series ID is assigned if there was none
        #expect(!next.isCompleted)
        #expect(next.completedAt == nil)
        #expect(next.droppedAt == nil)
        #expect(next.deferralCount == 0)                             // reset
        #expect(next.deferrals?.isEmpty ?? true)
        #expect(try series(w).count == 2)
    }

    @Test func finishingEarlySchedulesThePatternAfterTheDueDateNotTheOneAlreadyBooked() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 16, kind: .weekly, weekdays: "5")
        let next = try #require(TaskActions.complete(t, now: w.at(11, 10), boundary: w.boundary, context: w.context))   // done five days early
        #expect(next.dueDate == w.d(23).storedDate)                       // after max(due, completion day), not the 16th again
    }

    @Test func aMonthlyTaskRemembersItsDayOfMonthFromTheFirstCompletion() throws {
        let w = try TaskWorld()
        let t = TaskItem(title: "Rent", dueDate: CalendarDate(year: 2027, month: 1, day: 31)!.storedDate)
        t.repeatMode = .monthly
        w.context.insert(t)
        let boundary = w.boundary
        let next = try #require(TaskActions.complete(t, now: boundary.instant(of: CalendarDate(year: 2027, month: 1, day: 31)!, atMinute: 600), boundary: boundary, context: w.context))
        #expect(next.dueDate == CalendarDate(year: 2027, month: 2, day: 28)!.storedDate)
        #expect(next.repeatDayOfMonth == 31)
        let third = try #require(TaskActions.complete(next, now: boundary.instant(of: CalendarDate(year: 2027, month: 2, day: 28)!, atMinute: 600), boundary: boundary, context: w.context))
        #expect(third.dueDate == CalendarDate(year: 2027, month: 3, day: 31)!.storedDate)       // no drift to the 28th
    }

    @Test func thereIsNeverMoreThanOneLiveInstanceSoTwoDevicesCompletingDoNotDuplicate() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 9, kind: .weekly, weekdays: "5")
        let first = TaskActions.complete(t, now: w.at(9, 10), boundary: w.boundary, context: w.context)
        #expect(first != nil)
        // Another device already created the next instance and then this one syncs its own completion.
        t.isCompleted = false
        t.completedAt = nil
        let second = TaskActions.complete(t, now: w.at(9, 11), boundary: w.boundary, context: w.context)
        #expect(second == nil)                                       // (series, dueDate) already exists
        #expect(try series(w).count == 2)
    }

    @Test func completingTwiceDoesNothingTheSecondTime() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 9, kind: .daily)
        _ = TaskActions.complete(t, now: w.at(9, 10), boundary: w.boundary, context: w.context)
        let again = TaskActions.complete(t, now: w.at(9, 12), boundary: w.boundary, context: w.context)
        #expect(again == nil)
        #expect(t.completedAt == w.at(9, 10))
        #expect(try series(w).count == 2)
    }

    // MARK: Drop skips only this occurrence

    @Test func droppingARepeatingTaskSkipsThatOccurrenceAndTheSeriesContinues() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 9, kind: .weekly, weekdays: "5")
        let next = try #require(TaskActions.drop(t, now: w.at(9, 18), boundary: w.boundary, context: w.context))
        #expect(t.droppedAt == w.at(9, 18))
        #expect(!t.isCompleted)
        #expect(next.dueDate == w.d(16).storedDate)
        #expect(try series(w).count == 2)
    }

    @Test func droppingAOneOffJustDropsIt() throws {
        let w = try TaskWorld()
        let t = w.task("Call", due: 15)
        #expect(TaskActions.drop(t, now: w.at(15), boundary: w.boundary, context: w.context) == nil)
        #expect(t.droppedAt != nil)
        #expect(try series(w).count == 1)
    }

    // MARK: Stop repeating

    @Test func stoppingEndsTheSeriesAtTheLiveInstance() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 9, kind: .weekly, weekdays: "5")
        TaskActions.stopRepeating(t)
        #expect(t.repeatMode == .off)
        #expect(TaskActions.complete(t, now: w.at(9), boundary: w.boundary, context: w.context) == nil)
        #expect(try series(w).count == 1)
    }

    // MARK: Un-completing

    @Test func unCompletingAOneOffClearsTheCompletion() throws {
        let w = try TaskWorld()
        let t = w.task("Call", due: 15)
        _ = TaskActions.complete(t, now: w.at(15), boundary: w.boundary, context: w.context)
        try TaskActions.uncomplete(t, boundary: w.boundary, context: w.context)
        #expect(!t.isCompleted)
        #expect(t.completedAt == nil)
    }

    @Test func unCompletingARepeatingTaskRemovesAnUntouchedNextInstance() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 9, kind: .weekly, weekdays: "5")
        let next = try #require(TaskActions.complete(t, now: w.at(9, 10), boundary: w.boundary, context: w.context))
        try TaskActions.uncomplete(t, boundary: w.boundary, context: w.context)
        #expect(!t.isCompleted)
        #expect(try series(w).map(\.id) == [t.id])
        _ = next
    }

    @Test(arguments: ["completed", "deferred", "dropped", "timed", "edited"])
    func unCompletingIsRefusedOnceTheNextInstanceHasBeenTouched(touch: String) throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 9, kind: .weekly, weekdays: "5")
        let next = try #require(TaskActions.complete(t, now: w.at(9, 10), boundary: w.boundary, context: w.context))
        switch touch {
        case "completed": next.isCompleted = true; next.completedAt = w.at(16)
        case "deferred": next.deferralCount = 1
        case "dropped": next.droppedAt = w.at(16)
        case "timed": let s = WorkSession(); w.context.insert(s); s.task = next
        default: next.title = "Timesheet (Q4)"
        }
        #expect(throws: TaskActionError.alreadyRepeated) { try TaskActions.uncomplete(t, boundary: w.boundary, context: w.context) }
        #expect(t.isCompleted)                                        // nothing changed
        #expect(try series(w).count == 2)
    }

    @Test func unCompletingWorksWhenNoNextInstanceWasCreated() throws {
        let w = try TaskWorld()
        let t = repeating(w, due: 9, kind: .daily)
        t.isCompleted = true
        t.completedAt = w.at(9)
        try TaskActions.uncomplete(t, boundary: w.boundary, context: w.context)
        #expect(!t.isCompleted)
    }
}
