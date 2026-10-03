import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Night Planning part 2: the Review read model and Carry forward (docs/journeys/night-planning.md).
/// The evening of Thu 15 Oct 2026 (UTC) reviews the 15th and plans the 16th.
@MainActor
struct NightPlanningReviewTests {

    private func world() throws -> TaskWorld {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        return w
    }

    private func review(_ w: TaskWorld, now: Date? = nil) throws -> DayReview {
        try NightPlanning.review(reviewDate: w.d(15), boundary: w.boundary, now: now ?? w.at(15, 20, 5), context: w.context)
    }

    @Test func aFirstDayReadsAsEmptyNotAsFailure() throws {
        let w = try world()
        let r = try review(w)
        #expect(r.doneCount == 0)
        #expect(r.leftCount == 0)
        #expect(r.habitsDue == 0)
        #expect(r.anchors.isEmpty)
        #expect(r.timeSpent.isEmpty)
    }

    @Test func countsTasksDoneAndLeftForTheReviewedDayOnly() throws {
        let w = try world()
        let doneToday = w.task("Done today", due: 15); doneToday.isCompleted = true; doneToday.completedAt = w.at(15, 10)
        let doneYesterday = w.task("Done yesterday", due: 14); doneYesterday.isCompleted = true; doneYesterday.completedAt = w.at(14, 10)
        _ = w.task("Left", due: 15)
        _ = w.task("Overdue", due: 13)
        _ = w.task("Tomorrow", due: 16)
        let dropped = w.task("Dropped", due: 15); dropped.droppedAt = w.at(15, 12)
        let r = try review(w)
        #expect(r.completedTasks.map(\.title) == ["Done today"])
        #expect(r.doneCount == 1)
        #expect(r.leftCount == 2)                                            // "Left" and "Overdue"; dropped and future ones aren't left
        _ = (doneYesterday, dropped)
    }

    @Test func aTaskTheRolloverAlreadyMovedStillCountsAsLeftForTheDayUnderReview() throws {
        let w = try world()
        let t = w.task("Groceries", due: 15)
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 0, 30))     // 00:30 on the 16th
        #expect(t.dueDate == w.d(16).storedDate)
        let r = try NightPlanning.review(reviewDate: w.d(15), boundary: w.boundary, now: w.at(16, 0, 30), context: w.context)
        #expect(r.leftCount == 1)
    }

    @Test func habitsAreCountedAsDoneOfDueWithPartialsShownHonestly() throws {
        let w = try world()
        func habit(_ title: String, kind: HabitKind = .binary, target: Int = 1, amount: Int? = nil) -> HabitTimeWindow {
            let h = Habit(title: title); h.habitKind = kind; h.createdAt = w.at(1, 0); w.context.insert(h)
            let win = HabitTimeWindow(); win.target = target; w.context.insert(win); win.habit = h
            if let amount { let e = HabitEntry(); e.date = w.d(15).storedDate; e.amount = amount; e.target = target; w.context.insert(e); e.window = win }
            return win
        }
        _ = habit("Read", amount: 1)                                          // done
        _ = habit("Water", kind: .counted, target: 3, amount: 2)               // partial: "2/3"
        _ = habit("Stretch")                                                   // missed
        let paused = Habit(title: "Gym"); paused.createdAt = w.at(1, 0); w.context.insert(paused)
        paused.pauses = [HabitPause(from: w.d(10), to: nil, reason: .illness)]
        let pw = HabitTimeWindow(); w.context.insert(pw); pw.habit = paused    // paused: not counted
        let r = try review(w)
        #expect(r.habitsDue == 3)
        #expect(r.habitsDone == 1)
        let water = try #require(r.habits.first { $0.habit.title == "Water" })
        #expect(water.state == .partialHigh)
        #expect(water.amount == 2)
        #expect(water.target == 3)
        #expect(r.habits.first { $0.habit.title == "Stretch" }?.state == .missed)
    }

    @Test func aWeeklyTargetHabitOnlyAppearsOnTheDaysItWasDone() throws {
        let w = try world()
        let h = Habit(title: "Run"); h.targetPerWeek = 3; h.createdAt = w.at(1, 0); w.context.insert(h)
        let win = HabitTimeWindow(); w.context.insert(win); win.habit = h
        #expect(try review(w).habitsDue == 0)                                  // nothing logged: not a miss, so not listed
        let e = HabitEntry(); e.date = w.d(15).storedDate; e.amount = 1; e.target = 1; w.context.insert(e); e.window = win
        #expect(try review(w).habitsDue == 1)
        #expect(try review(w).habitsDone == 1)
    }

    @Test func anAnchorStillOpenAtReviewTimeReadsAsOpenNotMissed() throws {
        let w = try world()
        func anchor(_ title: String, hour: Int, minutes: Int, status: AttendanceStatus = .pending) -> Anchor {
            let a = Anchor(title: title); a.windowStart = w.at(15, hour); a.windowEnd = w.at(15, hour).addingTimeInterval(Double(minutes) * 60)
            a.occurrenceDate = w.d(15).storedDate; a.status = status; w.context.insert(a); return a
        }
        _ = anchor("Asr", hour: 15, minutes: 120, status: .attended)
        _ = anchor("Maghrib", hour: 17, minutes: 60)                           // closed at 18:00, never tapped: reads missed
        _ = anchor("Isha", hour: 19, minutes: 240)                             // open at 20:05
        let tomorrows = anchor("Tomorrow's", hour: 19, minutes: 60)
        tomorrows.occurrenceDate = w.d(16).storedDate
        let r = try review(w)
        #expect(r.anchors.map(\.anchor.title) == ["Asr", "Maghrib", "Isha"])
        #expect(r.anchors.map(\.status) == [.attended, .missed, .pending])
        #expect(r.anchors[2].windowState == .open)
    }

    @Test func timeSpentIsShownAgainstEachTasksEstimate() throws {
        let w = try world()
        let draft = w.task("Draft", due: 15, minutes: 60)
        func session(_ task: TaskItem, seconds: Int, day: Int = 15, outcome: SessionOutcome = .finished) {
            let s = WorkSession(); s.day = w.d(day).storedDate; s.actualSeconds = seconds; s.estimateMinutes = task.effortMinutes
            s.outcomeKind = outcome; w.context.insert(s); s.task = task
        }
        session(draft, seconds: 40 * 60)
        session(draft, seconds: 34 * 60, outcome: .abandoned)
        session(draft, seconds: 99 * 60, day: 14)                              // another day: not today's time
        session(draft, seconds: 5 * 60, outcome: .running)                     // still running: not counted yet
        let r = try review(w)
        let spent = try #require(r.timeSpent.first)
        #expect(r.timeSpent.count == 1)
        #expect(spent.task.id == draft.id)
        #expect(spent.actualMinutes == 74)
        #expect(spent.estimateMinutes == 60)
        #expect(r.totalActualMinutes == 74)
    }
}

@MainActor
struct NightPlanningCarryTests {

    private func world() throws -> TaskWorld {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        return w
    }

    private func session(_ w: TaskWorld) throws -> NightPlanningSession {
        try NightPlanning.open(forDate: w.d(16), mode: .evening, now: w.at(15, 21), context: w.context)
    }

    private func carry(_ w: TaskWorld, _ t: TaskItem, _ choice: CarryChoice, now: Date? = nil) throws -> CarryResult {
        try NightPlanning.carry(t, choice, reviewing: w.d(15), forDate: w.d(16), now: now ?? w.at(15, 21), boundary: w.boundary, context: w.context)
    }

    // MARK: Keep, Later, Drop

    @Test func keepMovesTheTaskToTomorrowAsADeferral() throws {
        let w = try world()
        let t = w.task("Groceries", due: 15)
        let result = try carry(w, t, .keep)
        #expect(t.dueDate == w.d(16).storedDate)
        #expect(t.deferralCount == 1)
        #expect(t.deferrals?.first?.day == w.d(15).storedDate)
        #expect(result.outcome?.kind == .deferred)
    }

    @Test func laterMovesItToTheChosenDayWithItsReasonOrParksItAsSomeday() throws {
        let w = try world()
        let a = w.task("A", due: 15), b = w.task("B", due: 15)
        _ = try carry(w, a, .later(w.d(20), .notReady))
        #expect(a.dueDate == w.d(20).storedDate)
        #expect(a.deferrals?.first?.reasonKind == .notReady)
        _ = try carry(w, b, .later(nil, .noLonger))                            // Someday, for a low task
        #expect(b.dueDate == nil)
        #expect(b.deferrals?.first?.reasonKind == .noLonger)
    }

    @Test func somedayIsRefusedForAnImportantTaskUntilItIsEased() throws {
        let w = try world()
        let t = w.task("Report", due: 15, importance: .high)
        #expect(throws: TaskRuleError.dateRequired) { _ = try carry(w, t, .later(nil, .tooMuch)) }
        #expect(t.deferralCount == 0)
    }

    @Test func dropIsASoftDeleteAndARepeatingTasksSeriesContinues() throws {
        let w = try world()
        let plain = w.task("Plain", due: 15)
        let weekly = w.task("Timesheet", due: 15); weekly.repeatMode = .weekly
        _ = try carry(w, plain, .drop)
        let result = try carry(w, weekly, .drop)
        #expect(plain.droppedAt == w.at(15, 21))
        #expect(weekly.droppedAt != nil)
        #expect(result.createdNext?.dueDate == w.d(22).storedDate)
    }

    // MARK: The third deferral

    @Test func fromTheThirdDeferralKeepNeedsThePickerAndChangesNothing() throws {
        let w = try world()
        let t = w.task("Slipping", due: 15, deferrals: 2)
        #expect(NightPlanning.keepNeedsPicker(t, reviewing: w.d(15)))
        #expect(throws: CarryError.pickerRequired) { _ = try carry(w, t, .keep) }
        #expect(t.deferralCount == 2)
        #expect(t.dueDate == w.d(15).storedDate)
        let result = try carry(w, t, .later(w.d(22), .tooMuch))                // the picker's choice works
        #expect(t.deferralCount == 3)
        #expect(result.outcome?.isStale == true)
    }

    @Test func theThirdDeferralEasesImportanceAndTheFifthSuggestsRemoval() throws {
        let w = try world()
        let important = w.task("Report", due: 15, importance: .high, deferrals: 2)
        let easing = try carry(w, important, .later(nil, .tooMuch))             // Someday is allowed because it is eased first
        #expect(easing.outcome?.easedImportance == true)
        #expect(important.importanceLevel == .low)
        #expect(important.dueDate == nil)

        let fifth = w.task("Never", due: 15, deferrals: 4)
        #expect(try carry(w, fifth, .later(w.d(22), .noLonger)).outcome?.suggestsRemoval == true)
    }

    @Test func aFirstOrSecondKeepIsInstant() throws {
        let w = try world()
        #expect(!NightPlanning.keepNeedsPicker(w.task("a", due: 15, deferrals: 0), reviewing: w.d(15)))
        #expect(!NightPlanning.keepNeedsPicker(w.task("b", due: 15, deferrals: 1), reviewing: w.d(15)))
    }

    // MARK: After midnight

    @Test func planningAfterMidnightRefinesTheRolloversRecordAndNeverDoubleCounts() throws {
        let w = try world()
        let t = w.task("Groceries", due: 15)
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 0, 30))
        let result = try NightPlanning.carry(t, .later(w.d(20), .tooMuch), reviewing: w.d(15), forDate: w.d(16), now: w.at(16, 0, 40), boundary: w.boundary, context: w.context)
        #expect(result.outcome?.kind == .refined)
        #expect(t.deferralCount == 1)
        #expect(t.dueDate == w.d(20).storedDate)
    }

    @Test func afterMidnightKeepNeedsThePickerOnlyIfTheCountIsAlreadyAtThree() throws {
        let w = try world()
        let two = w.task("Two", due: 15, deferrals: 1)
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 0, 30))     // the rollover makes it 2
        #expect(two.deferralCount == 2)
        #expect(!NightPlanning.keepNeedsPicker(two, reviewing: w.d(15)))        // refining the record leaves it at 2
        let three = w.task("Three", due: 15, deferrals: 2)
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 0, 31))     // idempotent for `two`, makes `three` 3
        #expect(three.deferralCount == 3)
        #expect(NightPlanning.keepNeedsPicker(three, reviewing: w.d(15)))
    }

    // MARK: Undo until the day is closed

    @Test func undoingKeepRestoresTheTaskAndRemovesTheRecord() throws {
        let w = try world()
        let t = w.task("Groceries", due: 15)
        let s = try session(w)
        let result = try carry(w, t, .keep)
        try NightPlanning.undoCarry(result, session: s, context: w.context)
        #expect(t.dueDate == w.d(15).storedDate)
        #expect(t.deferralCount == 0)
        #expect(t.deferrals?.isEmpty ?? true)
    }

    @Test func undoingARefinementRestoresTheRecordsEarlierChoice() throws {
        let w = try world()
        let t = w.task("Groceries", due: 15)
        let s = try session(w)
        _ = try carry(w, t, .keep)
        let second = try carry(w, t, .later(w.d(20), .notReady))
        try NightPlanning.undoCarry(second, session: s, context: w.context)
        #expect(t.deferralCount == 1)
        #expect(t.dueDate == w.d(16).storedDate)                                // back to the first choice
        #expect(t.deferrals?.count == 1)
        #expect(t.deferrals?.first?.reasonKind == .unspecified)
        #expect(t.deferrals?.first?.deferredTo == w.d(16).storedDate)
    }

    @Test func undoingEasingRestoresTheImportance() throws {
        let w = try world()
        let t = w.task("Report", due: 15, importance: .high, deferrals: 2)
        let s = try session(w)
        let result = try carry(w, t, .later(w.d(22), .tooMuch))
        #expect(t.importanceLevel == .low)
        try NightPlanning.undoCarry(result, session: s, context: w.context)
        #expect(t.importanceLevel == .high)
        #expect(t.deferralCount == 2)
        #expect(t.dueDate == w.d(15).storedDate)
    }

    @Test func undoingADropRestoresTheTaskAndRemovesARepeatingTasksNextInstance() throws {
        let w = try world()
        let weekly = w.task("Timesheet", due: 15); weekly.repeatMode = .weekly
        let s = try session(w)
        let result = try carry(w, weekly, .drop)
        #expect(try w.context.fetchCount(FetchDescriptor<TaskItem>()) == 2)
        try NightPlanning.undoCarry(result, session: s, context: w.context)
        #expect(weekly.droppedAt == nil)
        #expect(try w.context.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }

    @Test func nothingCanBeUndoneOnceTheDayIsClosed() throws {
        let w = try world()
        let t = w.task("Groceries", due: 15)
        let s = try session(w)
        let result = try carry(w, t, .keep)
        _ = try NightPlanning.close(s, boundary: w.boundary, now: w.at(15, 21, 30), context: w.context)
        #expect(throws: CarryError.dayClosed) { try NightPlanning.undoCarry(result, session: s, context: w.context) }
        #expect(t.dueDate == w.d(16).storedDate)
    }

    // MARK: What the Carry step shows

    @Test func theCarryListShowsEachTasksChoiceSoFar() throws {
        let w = try world()
        let pending = w.task("Pending", due: 15)
        let kept = w.task("Kept", due: 15)
        let parked = w.task("Parked", due: 15)
        let dropped = w.task("Dropped", due: 15)
        let done = w.task("Done", due: 15); done.isCompleted = true; done.completedAt = w.at(15, 10)
        let tomorrow = w.task("Tomorrow", due: 16)
        _ = try carry(w, kept, .keep)
        _ = try carry(w, parked, .later(nil, .noLonger))
        _ = try carry(w, dropped, .drop)
        let items = NightPlanning.carryItems(tasks: [pending, kept, parked, dropped, done, tomorrow], reviewing: w.d(15), boundary: w.boundary)
        let states = Dictionary(uniqueKeysWithValues: items.map { ($0.task.title, $0.state) })
        #expect(states["Pending"] == .pending)
        #expect(states["Kept"] == .moved(to: w.d(16)))
        #expect(states["Parked"] == .moved(to: nil))
        #expect(states["Dropped"] == .dropped)
        #expect(states["Done"] == nil)
        #expect(states["Tomorrow"] == nil)
        #expect(items.count == 4)
    }
}
