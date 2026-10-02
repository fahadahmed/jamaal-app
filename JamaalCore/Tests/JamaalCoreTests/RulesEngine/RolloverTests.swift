import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The lazy, idempotent day rollover (docs/architecture/rules-engine.md, "The day boundary"):
/// for every logical day that has ended it auto-defers what was left, finalises the day's
/// record from the day as lived, closes running timers at the boundary and ends an unfinished
/// planning session. Times are UTC with a midnight rollover unless a test says otherwise.
@MainActor
struct RolloverTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        context.insert(UserSettings())                       // 180-minute normal day, weekends low
        return context
    }

    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }   // 1 Oct 2026 is a Thursday
    private func date(_ day: Int) -> Date { d(day).storedDate }
    private func instant(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        boundary.instant(of: d(day), atMinute: hour * 60 + minute)
    }

    /// Runs the rollover as if it were `nowDay` at 09:00, having last processed `last`.
    @discardableResult
    private func catchUp(_ context: ModelContext, last: Int, nowDay: Int) throws -> RolloverReport {
        try Rollover.catchUp(in: context, boundary: boundary, lastProcessed: d(last), now: instant(nowDay, 9))
    }

    private func task(_ context: ModelContext, _ title: String, due: Int?, minutes: Int? = 30,
                      importance: Importance = .low) -> TaskItem {
        let t = TaskItem(title: title, dueDate: due.map(date), effortMinutes: minutes)
        t.importanceLevel = importance
        context.insert(t)
        return t
    }

    private func plan(_ context: ModelContext, _ day: Int) throws -> DayPlan? {
        try context.fetch(FetchDescriptor<DayPlan>()).first { $0.date == date(day) }
    }

    // MARK: Which days are processed

    @Test func processesOnlyEndedDaysOldestFirstAndReportsTheNewHighWaterMark() throws {
        let context = try makeContext()
        let report = try catchUp(context, last: 1, nowDay: 5)         // 2, 3, 4 have ended; 5 is today
        #expect(report.processedDays == [d(2), d(3), d(4)])
        #expect(report.lastProcessed == d(4))
    }

    @Test func nothingEndedMeansNothingToDo() throws {
        let context = try makeContext()
        let report = try catchUp(context, last: 4, nowDay: 5)
        #expect(report.processedDays.isEmpty)
        #expect(report.lastProcessed == d(4))
    }

    @Test func aFirstRunWithNoHistoryStartsFromYesterdayAndDoesNothing() throws {
        let context = try makeContext()
        let overdue = task(context, "Old", due: 1)
        let report = try Rollover.catchUp(in: context, boundary: boundary, lastProcessed: nil, now: instant(5, 9))
        #expect(report.processedDays.isEmpty)
        #expect(report.lastProcessed == d(4))
        #expect(overdue.deferralCount == 0)
    }

    // MARK: Auto-deferral

    @Test func anIncompleteDatedTaskIsDeferredOncePerEndedDayToTheNextDay() throws {
        let context = try makeContext()
        let t = task(context, "Groceries", due: 2)
        try catchUp(context, last: 1, nowDay: 3)                       // day 2 ended
        #expect(t.deferralCount == 1)
        #expect(t.dueDate == date(3))
        let record = try #require(t.deferrals?.first)
        #expect(record.day == date(2))
        #expect(record.reason == "unspecified")
        #expect(record.deferredTo == date(3))
        #expect(record.deferredOn == instant(3, 0))                    // the boundary, not "now"
    }

    @Test func eachMissedDayInACatchUpAddsOneDeferral() throws {
        let context = try makeContext()
        let t = task(context, "Groceries", due: 2)
        try catchUp(context, last: 1, nowDay: 5)                       // 2, 3, 4 ended
        #expect(t.deferralCount == 3)
        #expect(t.dueDate == date(5))
        #expect(Set(t.deferrals?.map(\.day) ?? []) == [date(2), date(3), date(4)])
    }

    @Test func completedDroppedFutureAndUndatedTasksAreLeftAlone() throws {
        let context = try makeContext()
        let done = task(context, "Done", due: 2); done.isCompleted = true; done.completedAt = instant(2, 10)
        let dropped = task(context, "Dropped", due: 2); dropped.droppedAt = instant(2, 11)
        let future = task(context, "Later", due: 9)
        let backlog = task(context, "Someday", due: nil)
        try catchUp(context, last: 1, nowDay: 3)
        for t in [done, dropped, future, backlog] { #expect(t.deferralCount == 0, "\(t.title)") }
        #expect(future.dueDate == date(9))
    }

    @Test func aTaskAlreadyDeferredThatDayIsNotDeferredAgain() throws {
        let context = try makeContext()
        let t = task(context, "Groceries", due: 2)
        let manual = DeferralRecord(); manual.day = date(2); manual.reason = "tooMuch"; manual.deferredTo = date(3)
        context.insert(manual); manual.task = t
        t.deferralCount = 1                                            // the user deferred it by hand on day 2
        try catchUp(context, last: 1, nowDay: 3)
        #expect(t.deferralCount == 1)
        #expect(t.deferrals?.count == 1)
    }

    @Test func runningTheSameDaysTwiceChangesNothing() throws {
        let context = try makeContext()
        let t = task(context, "Groceries", due: 2)
        try catchUp(context, last: 1, nowDay: 4)
        let count = t.deferralCount, due = t.dueDate
        let plansBefore = try context.fetchCount(FetchDescriptor<DayPlan>())
        try catchUp(context, last: 1, nowDay: 4)
        #expect(t.deferralCount == count)
        #expect(t.dueDate == due)
        #expect(t.deferrals?.count == count)
        #expect(try context.fetchCount(FetchDescriptor<DayPlan>()) == plansBefore)
    }

    @Test func theThirdDeferralEasesAMediumOrHighTaskToLow() throws {
        let context = try makeContext()
        let medium = task(context, "Report", due: 2, importance: .medium)
        let high = task(context, "Tax", due: 2, importance: .high)
        let lowTask = task(context, "Email", due: 2)
        try catchUp(context, last: 1, nowDay: 4)                       // two deferrals: unchanged
        #expect(medium.importanceLevel == .medium)
        #expect(high.importanceLevel == .high)
        try catchUp(context, last: 3, nowDay: 5)                       // the third
        #expect(medium.deferralCount == 3)
        #expect(medium.importanceLevel == .low)
        #expect(high.importanceLevel == .low)
        #expect(lowTask.importanceLevel == .low)
    }

    // MARK: DayPlan: created for a day with activity, finalised from the day as lived

    @Test func aDayWithNoActivityGetsNoDayPlan() throws {
        let context = try makeContext()
        try catchUp(context, last: 1, nowDay: 3)
        #expect(try plan(context, 2) == nil)
    }

    @Test(arguments: ["task", "session", "anchor", "habit", "planning"])
    func eachKindOfActivityCreatesTheDayPlan(kind: String) throws {
        let context = try makeContext()
        switch kind {
        case "task":
            let t = task(context, "Done", due: 2); t.isCompleted = true; t.completedAt = instant(2, 10)
        case "session":
            let s = WorkSession(); s.day = date(2); s.startedAt = instant(2, 10); context.insert(s)
        case "anchor":
            let a = Anchor(); a.status = .attended; a.resolvedAt = instant(2, 12); context.insert(a)
        case "habit":
            let w = HabitTimeWindow(); context.insert(w)
            let e = HabitEntry(); e.date = date(2); e.amount = 1; context.insert(e); e.window = w
        default:
            let n = NightPlanningSession(); n.forDate = date(3); n.skippedAt = instant(2, 21); context.insert(n)
        }
        try catchUp(context, last: 1, nowDay: 3)
        #expect(try plan(context, 2) != nil, "\(kind)")
    }

    @Test func heldTodayOnAnAvoidHabitIsActivityToo() throws {
        let context = try makeContext()
        let habit = Habit(title: "No sugar"); habit.habitKind = .avoid; context.insert(habit)
        let w = HabitTimeWindow(); context.insert(w); w.habit = habit
        let e = HabitEntry(); e.date = date(2); e.amount = 0; e.completedAt = instant(2, 20); context.insert(e); e.window = w
        try catchUp(context, last: 1, nowDay: 3)
        #expect(try plan(context, 2) != nil)
    }

    @Test func aHabitEntryThatWasUnTickedIsNotActivity() throws {
        let context = try makeContext()
        let w = HabitTimeWindow(); context.insert(w)
        let e = HabitEntry(); e.date = date(2); e.amount = 0; context.insert(e); e.window = w
        try catchUp(context, last: 1, nowDay: 3)
        #expect(try plan(context, 2) == nil)
    }

    @Test func aNewDayPlanTakesTheWeekdayDefaultLevel() throws {
        let context = try makeContext()
        let sat = task(context, "Sat", due: 3); sat.isCompleted = true; sat.completedAt = instant(3, 10)   // 3 Oct is a Saturday
        let fri = task(context, "Fri", due: 2); fri.isCompleted = true; fri.completedAt = instant(2, 10)
        try catchUp(context, last: 1, nowDay: 4)
        #expect(try plan(context, 3)?.capacityLevel == .low)
        #expect(try plan(context, 2)?.capacityLevel == .medium)
    }

    @Test func anExistingDayPlanKeepsTheUsersLevelAndPlanningTimestamp() throws {
        let context = try makeContext()
        let existing = DayPlan(); existing.date = date(2); existing.capacityLevel = .high; existing.planningCompletedAt = instant(1, 21)
        existing.freeMinutes = 300; existing.committedMinutes = 120
        context.insert(existing)
        try catchUp(context, last: 1, nowDay: 3)
        let p = try #require(try plan(context, 2))
        #expect(p.capacityLevel == .high)
        #expect(p.planningCompletedAt == instant(1, 21))
        #expect(p.freeMinutes == 300)                                  // free time is a later slice; untouched here
        #expect(p.committedMinutes == 120)
    }

    @Test func theLoadIsTheDayAsLivedNotAsPlannedAndSurvivesTheAutoDeferral() throws {
        let context = try makeContext()
        // 180-minute normal day, medium level: budget 180.
        let left1 = task(context, "Review", due: 2, minutes: 120)       // still live at the end of the day
        let left2 = task(context, "Slides", due: 1, minutes: 90)        // overdue, still live
        let done = task(context, "Reply", due: 2, minutes: 45); done.isCompleted = true; done.completedAt = instant(2, 10)
        let finishedYesterday = task(context, "Old", due: 1, minutes: 500); finishedYesterday.isCompleted = true; finishedYesterday.completedAt = instant(1, 10)
        let future = task(context, "Next week", due: 9, minutes: 500)
        _ = (left1, left2, finishedYesterday, future)
        try catchUp(context, last: 1, nowDay: 3)

        let p = try #require(try plan(context, 2))
        #expect(p.plannedTaskMinutes == 120 + 90 + 45)                  // live-due + completed that day
        #expect(p.loadScore == 142)                                     // 255 / 180
        #expect(p.wasOverloaded)

        // A second device reprocessing the same day sees the tasks already re-dated: same answer.
        try catchUp(context, last: 1, nowDay: 3)
        let again = try #require(try plan(context, 2))
        #expect(again.plannedTaskMinutes == 255)
        #expect(again.loadScore == 142)
    }

    @Test func aCompletedTaskCountsItsActualFocusTimeWhereItHasSessions() throws {
        let context = try makeContext()
        let t = task(context, "Draft", due: 2, minutes: 60); t.isCompleted = true; t.completedAt = instant(2, 15)
        let s1 = WorkSession(); s1.day = date(2); s1.actualSeconds = 40 * 60; s1.outcome = "abandoned"; s1.endedAt = instant(2, 12)
        let s2 = WorkSession(); s2.day = date(2); s2.actualSeconds = 34 * 60; s2.outcome = "finished"; s2.endedAt = instant(2, 15)
        context.insert(s1); context.insert(s2); s1.task = t; s2.task = t
        try catchUp(context, last: 1, nowDay: 3)
        let p = try #require(try plan(context, 2))
        #expect(p.completedEffortMinutes == 74)                         // actual, not the 60-minute estimate
        #expect(p.plannedTaskMinutes == 74)
    }

    @Test func missingDurationsCountAsZero() throws {
        let context = try makeContext()
        let t = task(context, "No estimate", due: 2, minutes: nil); t.isCompleted = true; t.completedAt = instant(2, 10)
        try catchUp(context, last: 1, nowDay: 3)
        let p = try #require(try plan(context, 2))
        #expect(p.plannedTaskMinutes == 0)
        #expect(p.completedEffortMinutes == 0)
    }

    @Test func completionIsFinishedOverFinishedPlusDeferredPlusDropped() throws {
        let context = try makeContext()
        let a = task(context, "A", due: 2); a.isCompleted = true; a.completedAt = instant(2, 10)
        let b = task(context, "B", due: 2); b.isCompleted = true; b.completedAt = instant(2, 11)
        let deferred = task(context, "C", due: 2)                        // auto-deferred at this rollover
        let dropped = task(context, "D", due: 2); dropped.droppedAt = instant(2, 18)
        _ = (deferred, dropped)
        try catchUp(context, last: 1, nowDay: 3)
        let p = try #require(try plan(context, 2))
        #expect(p.completionRate == 0.5)                                 // 2 of 4
    }

    @Test func aDayWithNothingToFinishHasARateOfZero() throws {
        let context = try makeContext()
        let s = WorkSession(); s.day = date(2); context.insert(s)         // activity, but no tasks
        try catchUp(context, last: 1, nowDay: 3)
        #expect(try plan(context, 2)?.completionRate == 0)
    }

    // MARK: Running sessions close at the boundary

    @Test func aRunningSessionClosesAtTheBoundaryNotAtNow() throws {
        let context = try makeContext()
        let s = WorkSession(); s.startedAt = instant(2, 23); s.day = date(2); s.pausedSeconds = 300
        context.insert(s)
        let report = try catchUp(context, last: 1, nowDay: 4)            // the device slept through day 2's midnight
        #expect(s.outcome == "autoClosed")
        #expect(s.endedAt == instant(3, 0))
        #expect(s.actualSeconds == 3600 - 300)                           // 23:00 to midnight, minus pauses
        #expect(report.closedSessions == 1)
    }

    @Test func aSessionPausedAtTheBoundaryStopsCountingAtThePause() throws {
        let context = try makeContext()
        let s = WorkSession(); s.startedAt = instant(2, 22); s.pausedAt = instant(2, 23); s.day = date(2)
        context.insert(s)
        try catchUp(context, last: 1, nowDay: 3)
        #expect(s.actualSeconds == 3600)                                  // an hour, then paused
        #expect(s.pausedAt == nil)
    }

    @Test func aSessionStartedAfterTheEndedDayIsLeftRunning() throws {
        let context = try makeContext()
        let s = WorkSession(); s.startedAt = instant(3, 8); s.day = date(3)
        context.insert(s)
        try catchUp(context, last: 1, nowDay: 3)                          // only day 2 has ended
        #expect(s.outcome == "running")
        #expect(s.endedAt == nil)
    }

    // MARK: Unfinished planning sessions end as skipped

    @Test func anUnfinishedPlanForADayThatEndedIsSkippedAtTheBoundary() throws {
        let context = try makeContext()
        let unfinished = NightPlanningSession(); unfinished.forDate = date(2); unfinished.currentStep = "build"
        let complete = NightPlanningSession(); complete.forDate = date(2); complete.isComplete = true
        let tomorrows = NightPlanningSession(); tomorrows.forDate = date(3)      // still being planned: its day hasn't ended
        context.insert(unfinished); context.insert(complete); context.insert(tomorrows)
        let report = try catchUp(context, last: 1, nowDay: 3)
        #expect(unfinished.skippedAt == instant(3, 0))
        #expect(unfinished.currentStep == "build")                       // choices already applied stay
        #expect(complete.skippedAt == nil)
        #expect(tomorrows.skippedAt == nil)
        #expect(report.endedPlanningSessions == 1)
    }

    // MARK: A custom rollover

    @Test func aLateRolloverAttributesTheSmallHoursToTheDayBeforeAndClosesAtThatBoundary() throws {
        let context = try makeContext()
        let late = DayBoundary(rolloverMinute: 180, timeZone: utc)        // 03:00
        let s = WorkSession(); s.startedAt = late.instant(of: d(2), atMinute: 23 * 60); s.day = date(2)   // 23:00 on day 2
        context.insert(s)
        let report = try Rollover.catchUp(in: context, boundary: late, lastProcessed: d(1), now: late.instant(of: d(3), atMinute: 4 * 60))
        #expect(report.processedDays == [d(2)])
        #expect(s.endedAt == late.startInstant(of: d(3)))                 // 03:00 on day 3
        #expect(s.endedAt == late.instant(of: d(3), atMinute: 180))
    }
}
