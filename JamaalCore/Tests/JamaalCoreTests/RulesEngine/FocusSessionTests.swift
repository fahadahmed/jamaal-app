import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Focus sessions (docs/schema/task.md, "Focus sessions"; rules engine module 8). Elapsed time is
/// always derived from `startedAt`; one live session at a time; overrun says nothing.
@MainActor
struct FocusSessionTests {

    // Thu 15 Oct 2026, UTC.

    private func begin(_ w: TaskWorld, _ task: TaskItem, hour: Int = 9, minute: Int = 0) throws -> WorkSession {
        try FocusSessions.begin(task: task, now: w.at(15, hour, minute), boundary: w.boundary, context: w.context)
    }

    // MARK: Elapsed, state

    @Test func beginningWritesTheSessionWithASnapshotOfTheEstimate() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15, minutes: 60)
        let s = try begin(w, task)
        #expect(s.startedAt == w.at(15, 9))
        #expect(s.day == w.d(15).storedDate)
        #expect(s.estimateMinutes == 60)
        #expect(s.outcomeKind == .running)
        #expect(s.endedAt == nil)
        #expect(s.task?.id == task.id)
        task.effortMinutes = 90                                      // a later edit doesn't rewrite what was estimated
        #expect(s.estimateMinutes == 60)
    }

    @Test func elapsedIgnoresPausesAndNeverAccumulatesInMemory() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("Draft", due: 15))
        #expect(FocusSessions.elapsedSeconds(of: s, at: w.at(15, 9, 20)) == 20 * 60)
        try FocusSessions.pause(s, now: w.at(15, 9, 20))
        #expect(FocusSessions.elapsedSeconds(of: s, at: w.at(15, 9, 50)) == 20 * 60)       // held while paused
        try FocusSessions.resume(s, now: w.at(15, 9, 50))
        #expect(s.pausedSeconds == 30 * 60)
        #expect(FocusSessions.elapsedSeconds(of: s, at: w.at(15, 10, 0)) == 30 * 60)       // 9:00–9:20 and 9:50–10:00
    }

    @Test func aClockSetBackNeverGivesNegativeTime() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("Draft", due: 15))
        #expect(FocusSessions.elapsedSeconds(of: s, at: w.at(15, 8, 0)) == 0)
    }

    @Test func theStateIsRunningThenOverrunThenPausedByExplicitPauseOnly() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("Draft", due: 15, minutes: 60))
        #expect(FocusSessions.state(of: s, at: w.at(15, 9, 59)) == .running)
        #expect(FocusSessions.state(of: s, at: w.at(15, 10, 1)) == .overrun)               // 61 of 60: neutral, just a state
        try FocusSessions.pause(s, now: w.at(15, 10, 5))
        #expect(FocusSessions.state(of: s, at: w.at(15, 10, 30)) == .paused)
        try FocusSessions.resume(s, now: w.at(15, 10, 30))
        s.endedAt = w.at(15, 11)
        #expect(FocusSessions.state(of: s, at: w.at(15, 12)) == .ended)
    }

    @Test func aTaskWithNoEstimateNeverOverruns() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("Tidy", due: 15, minutes: nil))
        #expect(FocusSessions.state(of: s, at: w.at(15, 20)) == .running)
    }

    @Test func pausingTwiceOrResumingWhenNotPausedIsRefused() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("Draft", due: 15))
        #expect(throws: FocusSessionError.notPaused) { try FocusSessions.resume(s, now: w.at(15, 9, 5)) }
        try FocusSessions.pause(s, now: w.at(15, 9, 5))
        #expect(throws: FocusSessionError.alreadyPaused) { try FocusSessions.pause(s, now: w.at(15, 9, 6)) }
    }

    // MARK: One live session

    @Test func aSecondBeginIsRefusedWhileOneIsLiveAndNamesIt() throws {
        let w = try TaskWorld()
        let a = w.task("A", due: 15), b = w.task("B", due: 15)
        let first = try begin(w, a)
        do {
            _ = try begin(w, b, hour: 10)
            Issue.record("expected the second Begin to be refused")
        } catch FocusSessionError.alreadyRunning(let liveID) {
            #expect(liveID == first.id)
        }
        #expect(try w.context.fetchCount(FetchDescriptor<WorkSession>()) == 1)
    }

    @Test func aHabitSessionCountsAsTheLiveOne() throws {
        let w = try TaskWorld()
        let window = HabitTimeWindow(); w.context.insert(window)
        _ = try FocusSessions.begin(habitWindow: window, now: w.at(15, 7), boundary: w.boundary, context: w.context)
        #expect(throws: (any Error).self) { try begin(w, w.task("A", due: 15)) }
        #expect(FocusSessions.liveSession(in: w.context)?.habitWindow?.id == window.id)
    }

    @Test func aCompletedOrDroppedTaskCannotBeBegun() throws {
        let w = try TaskWorld()
        let done = w.task("Done", due: 15); done.isCompleted = true
        let dropped = w.task("Dropped", due: 15); dropped.droppedAt = w.at(14)
        #expect(throws: FocusSessionError.taskNotLive) { try begin(w, done) }
        #expect(throws: FocusSessionError.taskNotLive) { try begin(w, dropped) }
    }

    @Test func aTaskNotDueTodayCanStillBeBegun() throws {
        let w = try TaskWorld()
        #expect(try begin(w, w.task("Later", due: 20)).task != nil)
    }

    // MARK: Finish

    @Test func doneCompletesTheTaskAndLogsTheTimeWithAnOptionalTimestampedNote() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15, minutes: 60)
        task.notes = "- [ ] outline"
        let s = try begin(w, task)
        try FocusSessions.pause(s, now: w.at(15, 9, 30))
        try FocusSessions.resume(s, now: w.at(15, 9, 40))
        let result = try FocusSessions.finish(s, as: .done, note: "Sent to Sam", now: w.at(15, 10, 14), boundary: w.boundary, context: w.context)
        #expect(s.outcomeKind == .finished)
        #expect(s.endedAt == w.at(15, 10, 14))
        #expect(s.actualSeconds == 64 * 60)                              // 74 minutes elapsed, 10 paused
        #expect(task.isCompleted)
        #expect(task.completedAt == w.at(15, 10, 14))
        #expect(task.notes == "- [ ] outline\n2026-10-15 10:14 — Sent to Sam")
        #expect(result.appendedNote == "2026-10-15 10:14 — Sent to Sam")
        #expect(FocusSessions.liveSession(in: w.context) == nil)
    }

    @Test func stopForNowEndsAsAbandonedKeepsTheTimeAndLeavesTheTaskLive() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15)
        let s = try begin(w, task)
        _ = try FocusSessions.finish(s, as: .stopForNow, note: nil, now: w.at(15, 9, 25), boundary: w.boundary, context: w.context)
        #expect(s.outcomeKind == .abandoned)
        #expect(s.actualSeconds == 25 * 60)
        #expect(!task.isCompleted)
        #expect(task.notes == nil)
    }

    @Test func aBlankNoteAppendsNothing() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15)
        let s = try begin(w, task)
        _ = try FocusSessions.finish(s, as: .done, note: "   ", now: w.at(15, 9, 25), boundary: w.boundary, context: w.context)
        #expect(task.notes == nil)
    }

    @Test func aPausedSessionClosesWithTheTimeUpToThePause() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("Draft", due: 15))
        try FocusSessions.pause(s, now: w.at(15, 9, 30))
        _ = try FocusSessions.finish(s, as: .stopForNow, note: nil, now: w.at(15, 11, 0), boundary: w.boundary, context: w.context)
        #expect(s.actualSeconds == 30 * 60)
        #expect(s.pausedAt == nil)
    }

    @Test func finishingASessionThatAlreadyEndedIsRefused() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("Draft", due: 15))
        _ = try FocusSessions.finish(s, as: .stopForNow, note: nil, now: w.at(15, 9, 10), boundary: w.boundary, context: w.context)
        #expect(throws: FocusSessionError.notRunning) {
            _ = try FocusSessions.finish(s, as: .done, note: nil, now: w.at(15, 9, 11), boundary: w.boundary, context: w.context)
        }
    }

    // MARK: Undo

    @Test func undoWithinFiveSecondsReopensTheSessionWithoutCountingTheToast() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15)
        let s = try begin(w, task)
        let end = w.at(15, 9, 30)
        let result = try FocusSessions.finish(s, as: .done, note: "Sent", now: end, boundary: w.boundary, context: w.context)
        try FocusSessions.undoFinish(s, result: result, now: end.addingTimeInterval(4), boundary: w.boundary, context: w.context)
        #expect(s.outcomeKind == .running)
        #expect(s.endedAt == nil)
        #expect(s.pausedSeconds == 4)                                    // the toast's seconds are paused time
        #expect(s.actualSeconds == 0)
        #expect(!task.isCompleted)
        #expect(task.completedAt == nil)
        #expect(task.notes == nil)                                       // the appended line goes too
    }

    @Test func undoAfterTheToastHasGoneIsRefused() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15)
        let s = try begin(w, task)
        let end = w.at(15, 9, 30)
        let result = try FocusSessions.finish(s, as: .done, note: nil, now: end, boundary: w.boundary, context: w.context)
        #expect(throws: FocusSessionError.undoExpired) {
            try FocusSessions.undoFinish(s, result: result, now: end.addingTimeInterval(6), boundary: w.boundary, context: w.context)
        }
        #expect(task.isCompleted)
    }

    @Test func undoOfARepeatingTasksFinishRemovesTheUntouchedNextInstance() throws {
        let w = try TaskWorld()
        let task = w.task("Timesheet", due: 15)
        task.repeatMode = .weekly
        let s = try begin(w, task)
        let end = w.at(15, 9, 30)
        let result = try FocusSessions.finish(s, as: .done, note: nil, now: end, boundary: w.boundary, context: w.context)
        #expect(try w.context.fetchCount(FetchDescriptor<TaskItem>()) == 2)
        try FocusSessions.undoFinish(s, result: result, now: end.addingTimeInterval(2), boundary: w.boundary, context: w.context)
        #expect(try w.context.fetchCount(FetchDescriptor<TaskItem>()) == 1)
        #expect(!task.isCompleted)
    }

    @Test func undoIsRefusedIfAnotherTimerHasStartedSince() throws {
        let w = try TaskWorld()
        let s = try begin(w, w.task("A", due: 15))
        let end = w.at(15, 9, 30)
        let result = try FocusSessions.finish(s, as: .stopForNow, note: nil, now: end, boundary: w.boundary, context: w.context)
        _ = try FocusSessions.begin(task: w.task("B", due: 15), now: end.addingTimeInterval(1), boundary: w.boundary, context: w.context)
        #expect(throws: (any Error).self) {
            try FocusSessions.undoFinish(s, result: result, now: end.addingTimeInterval(3), boundary: w.boundary, context: w.context)
        }
        #expect(s.outcomeKind == .abandoned)
    }

    // MARK: The settle sheet

    @Test func settlingWithDeferStopsTheTimerAndDefersTheTaskNormally() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15)
        let s = try begin(w, task)
        try FocusSessions.settle(s, as: .deferToTomorrow, now: w.at(15, 9, 40), boundary: w.boundary, context: w.context)
        #expect(s.outcomeKind == .deferred)
        #expect(s.actualSeconds == 40 * 60)
        #expect(task.deferralCount == 1)
        #expect(task.dueDate == w.d(16).storedDate)
        #expect(task.deferrals?.count == 1)
    }

    @Test func settlingWithDropStopsTheTimerAndDropsTheTask() throws {
        let w = try TaskWorld()
        let task = w.task("Draft", due: 15)
        let s = try begin(w, task)
        try FocusSessions.settle(s, as: .drop, now: w.at(15, 9, 40), boundary: w.boundary, context: w.context)
        #expect(s.outcomeKind == .dropped)
        #expect(task.droppedAt == w.at(15, 9, 40))
    }

    @Test func settlingWithDoneOrStopForNowBehavesLikeFinish() throws {
        let w = try TaskWorld()
        let a = w.task("A", due: 15), b = w.task("B", due: 15)
        let first = try begin(w, a)
        try FocusSessions.settle(first, as: .done, now: w.at(15, 9, 10), boundary: w.boundary, context: w.context)
        #expect(a.isCompleted)
        let second = try begin(w, b, hour: 9, minute: 20)
        try FocusSessions.settle(second, as: .stopForNow, now: w.at(15, 9, 30), boundary: w.boundary, context: w.context)
        #expect(second.outcomeKind == .abandoned)
        #expect(!b.isCompleted)
    }

    @Test func aHabitSessionOffersOnlyLogItAndStopForNow() throws {
        let w = try TaskWorld()
        let window = HabitTimeWindow(); w.context.insert(window)
        let s = try FocusSessions.begin(habitWindow: window, now: w.at(15, 7), boundary: w.boundary, context: w.context)
        #expect(throws: FocusSessionError.notForAHabit) {
            try FocusSessions.settle(s, as: .deferToTomorrow, now: w.at(15, 7, 10), boundary: w.boundary, context: w.context)
        }
        #expect(throws: FocusSessionError.notForAHabit) {
            try FocusSessions.settle(s, as: .drop, now: w.at(15, 7, 10), boundary: w.boundary, context: w.context)
        }
        try FocusSessions.settle(s, as: .logIt, now: w.at(15, 7, 12), boundary: w.boundary, context: w.context)
        #expect(s.outcomeKind == .finished)
    }

    // MARK: Closing with the task (G-25)

    @Test func resolvingATaskClosesItsLiveSessionWithTheMatchingOutcome() throws {
        let w = try TaskWorld()
        let done = w.task("Done", due: 15), deferred = w.task("Deferred", due: 15), dropped = w.task("Dropped", due: 15)

        let s1 = try begin(w, done)
        TaskActions.complete(done, now: w.at(15, 9, 30), boundary: w.boundary, context: w.context)
        #expect(s1.outcomeKind == .finished)
        #expect(s1.actualSeconds == 30 * 60)

        let s2 = try begin(w, deferred, hour: 10)
        _ = try TaskDeferral.defer(deferred, from: w.d(15), to: w.d(16), reason: .unspecified, now: w.at(15, 10, 20), boundary: w.boundary, context: w.context)
        #expect(s2.outcomeKind == .deferred)
        #expect(s2.actualSeconds == 20 * 60)

        let s3 = try begin(w, dropped, hour: 11)
        TaskActions.drop(dropped, now: w.at(15, 11, 5), boundary: w.boundary, context: w.context)
        #expect(s3.outcomeKind == .dropped)
        #expect(s3.actualSeconds == 5 * 60)
    }

    @Test func reschedulingATaskDoesNotStopItsTimer() throws {
        let w = try TaskWorld()
        let task = w.task("Later", due: 20)
        let s = try begin(w, task)
        _ = try TaskDeferral.defer(task, from: w.d(15), to: w.d(22), reason: .unspecified, now: w.at(15, 9, 5), boundary: w.boundary, context: w.context)
        #expect(s.outcomeKind == .running)
    }

    // MARK: Timed habits

    private func timedHabit(_ w: TaskWorld, target: Int = 15) -> HabitTimeWindow {
        let habit = Habit(title: "Qur'an"); habit.habitKind = .timed; habit.createdAt = w.at(1, 0); w.context.insert(habit)
        let window = HabitTimeWindow(); window.target = target; window.effortMinutes = target; w.context.insert(window); window.habit = habit
        return window
    }

    private func entry(_ w: TaskWorld, _ window: HabitTimeWindow, day: Int = 15) -> HabitEntry? {
        (window.entries ?? []).first { $0.date == w.d(day).storedDate }
    }

    @Test func aHabitSessionLogsItsMinutesToTodaysEntryRoundedFromTheTotalSeconds() throws {
        let w = try TaskWorld()
        let window = timedHabit(w)
        let a = try FocusSessions.begin(habitWindow: window, now: w.at(15, 7, 0), boundary: w.boundary, context: w.context)
        #expect(a.estimateMinutes == 15)
        try FocusSessions.settle(a, as: .logIt, now: w.at(15, 7, 5), boundary: w.boundary, context: w.context)      // 5 min
        let b = try FocusSessions.begin(habitWindow: window, now: w.at(15, 8, 0), boundary: w.boundary, context: w.context)
        try FocusSessions.settle(b, as: .stopForNow, now: w.at(15, 8, 5), boundary: w.boundary, context: w.context)  // 5 more, abandoned keeps the time
        let e = try #require(entry(w, window))
        #expect(e.amount == 10)
        #expect(e.target == 15)                                          // snapshot of the target
        #expect(e.completedAt == nil)
    }

    @Test func theRoundingIsOverAllTheSessionsNeverPerSession() throws {
        let w = try TaskWorld()
        let window = timedHabit(w)
        for (start, secs) in [(7, 40), (8, 40), (9, 40)] {                 // three 40-second sessions = 120 s = 2 min
            let s = try FocusSessions.begin(habitWindow: window, now: w.at(15, start), boundary: w.boundary, context: w.context)
            try FocusSessions.settle(s, as: .logIt, now: w.at(15, start).addingTimeInterval(Double(secs)), boundary: w.boundary, context: w.context)
        }
        #expect(entry(w, window)?.amount == 2)                           // per-session rounding would give 3
    }

    @Test func reachingTheTargetSetsTheCompletionTimeAndMoreDoesNotOverFill() throws {
        let w = try TaskWorld()
        let window = timedHabit(w)
        let s = try FocusSessions.begin(habitWindow: window, now: w.at(15, 7, 0), boundary: w.boundary, context: w.context)
        try FocusSessions.settle(s, as: .logIt, now: w.at(15, 7, 20), boundary: w.boundary, context: w.context)
        let e = try #require(entry(w, window))
        #expect(e.amount == 20)                                          // the entry holds the minutes; density caps the shade
        #expect(e.completedAt == w.at(15, 7, 20))
    }

    @Test func minutesAddedByHandAreAFinishedManualSessionThatFeedsTheSameTotal() throws {
        let w = try TaskWorld()
        let window = timedHabit(w)
        let s = try FocusSessions.begin(habitWindow: window, now: w.at(15, 7, 0), boundary: w.boundary, context: w.context)
        try FocusSessions.settle(s, as: .logIt, now: w.at(15, 7, 6), boundary: w.boundary, context: w.context)
        let manual = FocusSessions.addMinutes(8, to: window, on: w.d(15), now: w.at(15, 20), context: w.context)
        #expect(manual.outcomeKind == .manual)
        #expect(manual.actualSeconds == 8 * 60)
        #expect(manual.endedAt == nil)                                    // no timing of its own, and never "live"
        #expect(FocusSessions.liveSession(in: w.context) == nil)
        #expect(entry(w, window)?.amount == 14)
    }

    @Test func aPastDayCorrectionAddsToThatDaysEntryNotTodays() throws {
        let w = try TaskWorld()
        let window = timedHabit(w)
        _ = FocusSessions.addMinutes(15, to: window, on: w.d(12), now: w.at(15, 9), context: w.context)
        #expect(entry(w, window, day: 12)?.amount == 15)
        #expect(entry(w, window, day: 12)?.completedAt != nil)
        #expect(entry(w, window, day: 15) == nil)
    }

    @Test func reopeningAHabitSessionTakesItsMinutesBackOutOfTheEntry() throws {
        let w = try TaskWorld()
        let window = timedHabit(w)
        let s = try FocusSessions.begin(habitWindow: window, now: w.at(15, 7, 0), boundary: w.boundary, context: w.context)
        let end = w.at(15, 7, 10)
        let result = try FocusSessions.finish(s, as: .done, note: nil, now: end, boundary: w.boundary, context: w.context)
        #expect(entry(w, window)?.amount == 10)
        try FocusSessions.undoFinish(s, result: result, now: end.addingTimeInterval(2), boundary: w.boundary, context: w.context)
        #expect(entry(w, window)?.amount == 0)
        #expect(entry(w, window)?.completedAt == nil)
    }

    // MARK: Pick it back up

    @Test func anAutoClosedSessionOffersOneRowTomorrowUntilTheTaskIsActedOn() throws {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        let task = w.task("Draft", due: 15, minutes: 60)
        let s = try begin(w, task, hour: 23, minute: 0)
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 8))
        #expect(s.outcomeKind == .autoClosed)
        let rows = FocusSessions.pickUpRows(tasks: [task], today: w.d(16), boundary: w.boundary)
        #expect(rows.map(\.task.title) == ["Draft"])
        #expect(rows.first?.session.id == s.id)
        // Picking it up (a new session) makes the row go away.
        _ = try FocusSessions.begin(task: task, now: w.at(16, 9), boundary: w.boundary, context: w.context)
        #expect(FocusSessions.pickUpRows(tasks: [task], today: w.d(16), boundary: w.boundary).isEmpty)
    }

    @Test func thePickUpRowGoesWhenTheTaskIsCompletedOrDroppedOrTheDayEnds() throws {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        let task = w.task("Draft", due: 15)
        _ = try begin(w, task, hour: 23)
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 8))
        #expect(FocusSessions.pickUpRows(tasks: [task], today: w.d(17), boundary: w.boundary).isEmpty)      // a day later
        task.isCompleted = true
        #expect(FocusSessions.pickUpRows(tasks: [task], today: w.d(16), boundary: w.boundary).isEmpty)
    }

    // MARK: The approaching edge for the chip

    private func anchor(_ w: TaskWorld, _ title: String, start: Date, minutes: Int, flexible: Bool = false, status: AttendanceStatus = .pending) -> Anchor {
        let a = Anchor(title: title)
        a.windowStart = start
        a.windowEnd = start.addingTimeInterval(Double(minutes) * 60)
        a.status = status
        w.context.insert(a)
        if flexible {
            let rule = AnchorRule(title: title); rule.placementKind = .flexible; w.context.insert(rule); a.rule = rule
        }
        return a
    }

    @Test func anOpenAnchorClosingSoonOutranksOneAboutToOpen() throws {
        let w = try TaskWorld()
        let asr = anchor(w, "Asr", start: w.at(15, 15, 0), minutes: 60)               // closes 16:00
        let maghrib = anchor(w, "Maghrib", start: w.at(15, 16, 12), minutes: 30)        // opens in 12 minutes
        let edge = try #require(FocusSessions.approachingEdge(anchors: [asr, maghrib], now: w.at(15, 15, 50)))
        #expect(edge.title == "Asr")
        #expect(edge.kind == .closing)
        #expect(edge.minutes == 10)
    }

    @Test func aFixedAnchorOpeningWithinThirtyMinutesIsShownOtherwiseNothing() throws {
        let w = try TaskWorld()
        let maghrib = anchor(w, "Maghrib", start: w.at(15, 18, 40), minutes: 30)
        let edge = try #require(FocusSessions.approachingEdge(anchors: [maghrib], now: w.at(15, 18, 28)))
        #expect(edge.kind == .opening)
        #expect(edge.minutes == 12)
        #expect(FocusSessions.approachingEdge(anchors: [maghrib], now: w.at(15, 17, 50)) == nil)       // 50 minutes away
    }

    @Test func flexibleDecidedAndOpenButNotClosingAnchorsNeverAppear() throws {
        let w = try TaskWorld()
        let bins = anchor(w, "Bin night", start: w.at(15, 18, 40), minutes: 30, flexible: true)
        let attended = anchor(w, "Asr", start: w.at(15, 15, 0), minutes: 60, status: .attended)
        let open = anchor(w, "Dhuhr", start: w.at(15, 12, 0), minutes: 240)                           // open, plenty of time left
        #expect(FocusSessions.approachingEdge(anchors: [bins], now: w.at(15, 18, 30)) == nil)
        #expect(FocusSessions.approachingEdge(anchors: [attended], now: w.at(15, 15, 50)) == nil)
        #expect(FocusSessions.approachingEdge(anchors: [open], now: w.at(15, 12, 30)) == nil)
    }

    @Test func theMostUrgentOfSeveralClosingAnchorsWins() throws {
        let w = try TaskWorld()
        let later = anchor(w, "Later", start: w.at(15, 15, 0), minutes: 60)                            // closes 16:00, closing soon from 15:45
        let sooner = anchor(w, "Sooner", start: w.at(15, 15, 30), minutes: 28)                         // closes 15:58, closing soon from 15:48
        let edge = try #require(FocusSessions.approachingEdge(anchors: [later, sooner], now: w.at(15, 15, 50)))
        #expect(edge.title == "Sooner")
        #expect(edge.minutes == 8)
    }

    @Test func theRolloverCarriesAnInProgressTaskToTheNextDayWithoutCountingADeferral() throws {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        let working = w.task("In progress", due: 15)
        let idle = w.task("Idle", due: 15)
        _ = try begin(w, working, hour: 23)
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 8))
        #expect(working.dueDate == w.d(16).storedDate)                  // carried to tomorrow
        #expect(working.deferralCount == 0)                              // it was in progress: no deferral, no record
        #expect(working.deferrals?.isEmpty ?? true)
        #expect(idle.deferralCount == 1)                                 // an untouched task is still auto-deferred
    }
}

/// Time tracked on a task, for its row ("Timing · 24 min", "Done 10:55 · 74 min").
@MainActor
struct TrackedTimeTests {
    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        boundary.instant(of: CalendarDate(year: 2026, month: 10, day: 5)!, atMinute: hour * 60 + minute)
    }
    private func fixture() throws -> (ModelContext, TaskItem) {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        let t = TaskItem(title: "Draft", effortMinutes: 60)
        c.insert(t)
        return (c, t)
    }

    @Test func aTaskNeverTimedHasNoTrackedTime() throws {
        let (_, t) = try fixture()
        #expect(FocusSessions.trackedSeconds(of: t, at: at(9)) == 0)
    }

    @Test func aLiveSessionCountsItsElapsedTime() throws {
        let (c, t) = try fixture()
        _ = try FocusSessions.begin(task: t, now: at(9), boundary: boundary, context: c)
        #expect(FocusSessions.trackedSeconds(of: t, at: at(9, 24)) == 24 * 60)
    }

    @Test func endedSessionsAddUpWithTheLiveOne() throws {
        let (c, t) = try fixture()
        let first = try FocusSessions.begin(task: t, now: at(9), boundary: boundary, context: c)
        _ = try FocusSessions.finish(first, as: .stopForNow, note: nil, now: at(9, 30), boundary: boundary, context: c)
        _ = try FocusSessions.begin(task: t, now: at(11), boundary: boundary, context: c)
        #expect(FocusSessions.trackedSeconds(of: t, at: at(11, 10)) == 40 * 60)
    }

    @Test func pausesAreNotWorkAndAPausedSessionStopsCounting() throws {
        let (c, t) = try fixture()
        let s = try FocusSessions.begin(task: t, now: at(9), boundary: boundary, context: c)
        try FocusSessions.pause(s, now: at(9, 20))
        #expect(FocusSessions.trackedSeconds(of: t, at: at(9, 50)) == 20 * 60)
    }

    @Test func aTaskWithNoSessionsRelationshipIsZero() {
        #expect(FocusSessions.trackedSeconds(of: TaskItem(title: "x"), at: at(9)) == 0)
    }
}
