import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Day review's read model and the two-day fix window (docs/journeys/coming-up-and-day-review.md).
/// Today is Thu 15 Oct 2026 (UTC); the day under review is Mon 12 Oct unless stated.
@MainActor
struct PastDayTests {
    private func world() throws -> TaskWorld {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        return w
    }

    private func day(_ w: TaskWorld, _ n: Int = 12, today: Int = 15) throws -> PastDay {
        try PastDay.read(on: w.d(n), today: w.d(today), boundary: w.boundary, now: w.at(today, 9), context: w.context)
    }

    private func defer_(_ t: TaskItem, _ w: TaskWorld, from: Int, to: Int?, reason: DeferralReason = .reschedule) {
        let r = DeferralRecord(); r.day = w.d(from).storedDate; r.deferredTo = to.map { w.d($0).storedDate }; r.reasonKind = reason
        w.context.insert(r); r.task = t
    }

    @Test func tasksAreDoneDeferredOrCarriedOnTheDayTheyHappened() throws {
        let w = try world()
        let done = w.task("Reply to Sam", due: 12); done.isCompleted = true; done.completedAt = w.at(12, 9, 12)
        let moved = w.task("Call the clinic", due: 14); defer_(moved, w, from: 12, to: 14)
        let auto = w.task("Architecture review", due: 13, created: 2); defer_(auto, w, from: 12, to: 13, reason: .unspecified)
        let other = w.task("Another day", due: 14); other.isCompleted = true; other.completedAt = w.at(13, 10)
        let d = try day(w)
        #expect(d.tasks.map(\.task.title) == ["Reply to Sam", "Call the clinic", "Architecture review"])
        #expect(d.tasks[0].outcome == .done(at: w.at(12, 9, 12)))
        #expect(d.tasks[1].outcome == .deferred(to: w.d(14)))
        #expect(d.tasks[2].outcome == .carried(to: w.d(13)), "an automatic deferral reads as carried")
        #expect(d.doneCount == 1 && d.plannedCount == 3)
        _ = other
    }

    @Test func aDroppedTaskIsNotListedAndNotCounted() throws {
        let w = try world()
        let t = w.task("Gone", due: 12); t.droppedAt = w.at(12, 15)
        let d = try day(w)
        #expect(d.tasks.isEmpty)
        #expect(d.plannedCount == 0)
    }

    @Test func aTaskTheRolloverHasNotMovedYetIsNotDone() throws {
        let w = try world()
        w.task("Left", due: 12)
        let d = try day(w)
        #expect(d.tasks.map(\.outcome) == [.notDone])
    }

    @Test func markDoneIsOfferedOnlyForANotDoneTaskInsideTheTwoDayWindow() throws {
        let w = try world()
        let t = w.task("Draft", due: 14); defer_(t, w, from: 14, to: 15, reason: .unspecified)
        let yesterday = try day(w, 14)
        #expect(yesterday.tasks.first?.canMarkDone == true)
        let theDayBefore = try PastDay.read(on: w.d(13), today: w.d(15), boundary: w.boundary, now: w.at(15, 9), context: w.context)
        #expect(theDayBefore.tasks.isEmpty)
        let t2 = w.task("Old", due: 12); defer_(t2, w, from: 12, to: 13, reason: .unspecified)
        #expect(try day(w, 12).tasks.first?.canMarkDone == false, "three days back is locked")
        let done = w.task("Done", due: 14); done.isCompleted = true; done.completedAt = w.at(14, 10)
        #expect(try day(w, 14).tasks.first { $0.task.title == "Done" }?.canMarkDone == false)
    }

    @Test func theFixWindowIsYesterdayAndTheDayBeforeOnly() {
        let today = CalendarDate(year: 2026, month: 10, day: 15)!
        #expect(PastDay.canFixTasks(on: today.addingDays(-1), today: today))
        #expect(PastDay.canFixTasks(on: today.addingDays(-2), today: today))
        #expect(!PastDay.canFixTasks(on: today.addingDays(-3), today: today))
        #expect(!PastDay.canFixTasks(on: today, today: today))
        #expect(!PastDay.canFixTasks(on: today.addingDays(1), today: today))
    }

    @Test func capacityUsedAndTheCloseTimeComeFromTheDayRecord() throws {
        let w = try world()
        let plan = DayPlan(); plan.date = w.d(12).storedDate; plan.capacityLevel = .medium; plan.completedEffortMinutes = 135
        w.context.insert(plan)
        let closing = NightPlanningSession(); closing.forDate = w.d(13).storedDate; closing.isComplete = true; closing.completedAt = w.at(12, 22, 40)
        w.context.insert(closing)
        let d = try day(w)
        #expect(d.level == .medium)
        #expect(d.usedMinutes == 135)
        #expect(d.budgetMinutes == 180, "medium is the normal day, three hours by default")
        #expect(d.closedAt == w.at(12, 22, 40))
    }

    @Test func aDayWithNoRecordHasNoCloseTimeAndUsedComesFromTheDoneTasks() throws {
        let w = try world()
        let t = w.task("Reply", due: 12, minutes: 20); t.isCompleted = true; t.completedAt = w.at(12, 9)
        let d = try day(w)
        #expect(d.closedAt == nil)
        #expect(d.usedMinutes == 20)
    }

    @Test func anchorsAreReadWithTheirOutcomeAndHabitsWithTheirProgress() throws {
        let w = try world()
        let a = Anchor(title: "School run"); a.occurrenceDate = w.d(12).storedDate
        a.windowStart = w.at(12, 15); a.windowEnd = w.at(12, 16); a.status = .attended; a.resolvedAt = w.at(12, 15, 2)
        w.context.insert(a)
        let missed = Anchor(title: "Salah"); missed.occurrenceDate = w.d(12).storedDate
        missed.windowStart = w.at(12, 12); missed.windowEnd = w.at(12, 13); missed.status = .missed
        w.context.insert(missed)
        let d = try day(w)
        #expect(d.anchors.map(\.anchor.title) == ["Salah", "School run"], "by window start")
        #expect(d.anchors.map(\.status) == [.missed, .attended])
        #expect(d.anchorsAttended == 1 && d.anchorsCounted == 2)
    }

    @Test func firstDayIsTheEarliestDayWithAnyDataBeforeToday() throws {
        let w = try world()
        #expect(try PastDay.firstDay(before: w.d(15), boundary: w.boundary, context: w.context) == nil, "nothing yet")
        let today = TaskItem(title: "New"); today.createdAt = w.at(15, 8); w.context.insert(today)
        #expect(try PastDay.firstDay(before: w.d(15), boundary: w.boundary, context: w.context) == nil, "created today is not a past day")
        let older = TaskItem(title: "Older"); older.createdAt = w.at(10, 8); w.context.insert(older)
        #expect(try PastDay.firstDay(before: w.d(15), boundary: w.boundary, context: w.context) == w.d(10))
        let plan = DayPlan(); plan.date = w.d(8).storedDate; w.context.insert(plan)
        #expect(try PastDay.firstDay(before: w.d(15), boundary: w.boundary, context: w.context) == w.d(8))
    }

    @Test func previousGoesBackToTheFirstDayAndNextStopsAtYesterday() throws {
        let w = try world()
        let older = TaskItem(title: "Older"); older.createdAt = w.at(10, 8); w.context.insert(older)
        let nav = try PastDay.neighbours(of: w.d(11), today: w.d(15), boundary: w.boundary, context: w.context)
        #expect(nav.previous == w.d(10))
        #expect(nav.next == w.d(12))
        let first = try PastDay.neighbours(of: w.d(10), today: w.d(15), boundary: w.boundary, context: w.context)
        #expect(first.previous == nil)
        let yesterday = try PastDay.neighbours(of: w.d(14), today: w.d(15), boundary: w.boundary, context: w.context)
        #expect(yesterday.next == nil, "today has its own screen")
    }

    // MARK: Yesterday row

    @Test func theYesterdayRowIsHiddenOnTheFirstDayAndSaysNotPlannedAfterAnUnplannedDay() throws {
        let w = try world()
        #expect(try PastDay.yesterdayRow(today: w.d(15), boundary: w.boundary, context: w.context) == .hidden)
        let older = TaskItem(title: "Older"); older.createdAt = w.at(10, 8); w.context.insert(older)
        #expect(try PastDay.yesterdayRow(today: w.d(15), boundary: w.boundary, context: w.context) == .notPlanned)
    }

    @Test func theYesterdayRowCountsDoneOfPlannedWhenYesterdayWasPlanned() throws {
        let w = try world()
        let plan = DayPlan(); plan.date = w.d(14).storedDate; plan.planningCompletedAt = w.at(13, 21); w.context.insert(plan)
        let a = w.task("A", due: 14); a.isCompleted = true; a.completedAt = w.at(14, 10)
        let b = w.task("B", due: 14); b.isCompleted = true; b.completedAt = w.at(14, 11)
        let c = w.task("C", due: 14); defer_(c, w, from: 14, to: 15, reason: .unspecified)
        #expect(try PastDay.yesterdayRow(today: w.d(15), boundary: w.boundary, context: w.context) == .summary(done: 2, planned: 3))
    }

    // MARK: Ticking a missed task

    @Test func tickingAMissedTaskRecordsItOnThatDayAtItsEnd() throws {
        let w = try world()
        let plan = DayPlan(); plan.date = w.d(14).storedDate; plan.completedEffortMinutes = 30; w.context.insert(plan)
        let t = w.task("Draft", due: 15, minutes: 45); defer_(t, w, from: 14, to: 15, reason: .unspecified)
        try TaskActions.completeOnPastDay(t, day: w.d(14), today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        #expect(t.isCompleted)
        #expect(w.boundary.logicalDate(at: try #require(t.completedAt)) == w.d(14), "it counts on the day it belongs to")
        #expect(plan.completedEffortMinutes == 75)
        #expect(try day(w, 14).tasks.first?.outcome == .done(at: try #require(t.completedAt)))
    }

    @Test func tickingOutsideTheWindowIsRefusedAndChangesNothing() throws {
        let w = try world()
        let t = w.task("Old", due: 15); defer_(t, w, from: 11, to: 15, reason: .unspecified)
        #expect(throws: TaskActionError.outsideFixWindow) {
            try TaskActions.completeOnPastDay(t, day: w.d(11), today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        }
        #expect(!t.isCompleted && t.completedAt == nil)
    }

    @Test func tickingARepeatingTaskMakesItsNextInstanceOnceAndNeverTwo() throws {
        let w = try world()
        let t = w.task("Timesheet", due: 15); t.repeatKind = "weekly"; t.repeatWeekdays = "5"; t.seriesID = UUID()
        defer_(t, w, from: 14, to: 15, reason: .unspecified)
        try TaskActions.completeOnPastDay(t, day: w.d(14), today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        let live = try w.context.fetch(FetchDescriptor<TaskItem>()).filter { !$0.isCompleted && $0.seriesID == t.seriesID }
        #expect(live.count == 1)
        #expect(live.first?.dueDate == w.d(16).storedDate, "the next Friday after the day it was ticked for")
    }
}
