import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Wellbeing, part 1 (docs/architecture/rules-engine.md, module 5): derived only from behaviour
/// (tasks, Anchors, habits, load), no self-reporting. Today is Thu 15 Oct 2026, so the window is the
/// 14 days ending yesterday: Thu 1 – Wed 14 Oct. UTC.
@MainActor
struct WellbeingTests {

    private func world() throws -> TaskWorld { try TaskWorld() }

    private func d(_ day: Int, month: Int = 10) -> CalendarDate { CalendarDate(year: 2026, month: month, day: day)! }

    /// An active day: a `DayPlan` with its as-lived numbers.
    @discardableResult
    private func plan(_ w: TaskWorld, _ day: CalendarDate, completion: Double = 1, basis: Int = 3, overloaded: Bool = false) -> DayPlan {
        let p = DayPlan()
        p.date = day.storedDate
        p.completionRate = completion
        p.completionBasis = basis
        p.wasOverloaded = overloaded
        w.context.insert(p)
        return p
    }

    private func active(_ w: TaskWorld, days: ClosedRange<Int>, month: Int = 10, completion: Double = 1, overloaded: Bool = false) {
        for day in days { plan(w, d(day, month: month), completion: completion, overloaded: overloaded) }
    }

    private func snapshot(_ w: TaskWorld, today: Int = 15) throws -> WellbeingSnapshot {
        try Wellbeing.snapshot(now: w.at(today, 9), boundary: w.boundary, context: w.context)
    }

    private func score(_ s: WellbeingSnapshot) -> Int? {
        if case .active(let score, _) = s.state { return score }
        return nil
    }

    // MARK: Gathering data

    @Test func underSevenActiveDaysInTheLastFourteenIsGatheringData() throws {
        let w = try world()
        active(w, days: 8...13)                                              // six active days
        let s = try snapshot(w)
        #expect(s.state == .gathering(activeDays: 6, needed: 7))
        #expect(s.activeDays == 6)
        #expect(s.sparkline.allSatisfy { $0.score == nil })
    }

    @Test func todayAndDaysOlderThanTheWindowAreNotCounted() throws {
        let w = try world()
        active(w, days: 8...12)                                              // five inside the window
        plan(w, d(15))                                                        // today: not finished
        active(w, days: 10...13, month: 9)                                    // 10–13 Sep: far outside
        #expect(try snapshot(w).activeDays == 5)
    }

    @Test func sevenActiveDaysMakesTheScoreActive() throws {
        let w = try world()
        active(w, days: 1...7)
        #expect(try snapshot(w).state != .gathering(activeDays: 7, needed: 7))
        #expect(try score(snapshot(w)) != nil)
    }

    @Test func aQuietStretchPausesTheScoreRatherThanLoweringIt() throws {
        let w = try world()
        active(w, days: 1...7, completion: 0.5)
        #expect(try score(snapshot(w, today: 15)) != nil)
        // A week later the window is 8–21 Oct, which holds none of those days: nothing to say, not a fall.
        #expect(try snapshot(w, today: 22).state == .gathering(activeDays: 0, needed: 7))
    }

    // MARK: The score

    @Test func withOnlyTasksAndLoadTheWeightsRescaleBetweenThem() throws {
        let w = try world()
        active(w, days: 1...7, completion: 0.8)                              // tasks 80, load 100 (nothing overloaded)
        let s = try snapshot(w)
        #expect(s.parts.map(\.kind) == [.tasks, .load])
        #expect(score(s) == 87)                                              // (35×80 + 20×100) ÷ 55 = 87.3
        #expect(s.completionPercent == 80)
    }

    @Test func aDayWithNothingToFinishIsLeftOutOfTheTasksPart() throws {
        let w = try world()
        active(w, days: 1...6, completion: 0.9)
        plan(w, d(7), completion: 0, basis: 0)                                // active, but nothing to finish: not a zero
        let tasks = try #require(try snapshot(w).parts.first { $0.kind == .tasks })
        #expect(tasks.value == 90)
    }

    @Test func loadIsTheShareOfActiveDaysThatWereNotOverloaded() throws {
        let w = try world()
        for day in 1...7 { plan(w, d(day), overloaded: day <= 2) }           // 2 of 7 overloaded
        let s = try snapshot(w)
        let load = try #require(s.parts.first { $0.kind == .load })
        #expect(abs(load.value - 500.0 / 7.0) < 0.01)                         // 71.4
        #expect(s.heavyDays == 2)
    }

    @Test func withNoTaskDataAtAllOnlyLoadCounts() throws {
        let w = try world()
        for day in 1...7 { plan(w, d(day), completion: 0, basis: 0, overloaded: false) }
        let s = try snapshot(w)
        #expect(s.parts.map(\.kind) == [.load])
        #expect(score(s) == 100)
        #expect(s.completionPercent == nil)
    }

    // MARK: Anchors

    private func anchor(_ w: TaskWorld, day: Int, status: AttendanceStatus, hour: Int = 6, minutes: Int = 60) -> Anchor {
        let a = Anchor(title: "Anchor"); a.windowStart = w.at(day, hour); a.windowEnd = w.at(day, hour).addingTimeInterval(Double(minutes) * 60)
        a.occurrenceDate = w.d(day).storedDate; a.status = status; w.context.insert(a); return a
    }

    @Test func anchorsAreAttendedOverAttendedPlusMissedWithSkippedAndDelegatedLeftOut() throws {
        let w = try world()
        active(w, days: 1...7)
        for day in 1...7 {
            _ = anchor(w, day: day, status: .attended, hour: 5)
            _ = anchor(w, day: day, status: .missed, hour: 6)
            _ = anchor(w, day: day, status: .skipped, hour: 7)              // not a miss, not counted
            _ = anchor(w, day: day, status: .delegated, hour: 8)
        }
        let anchors = try #require(try snapshot(w).parts.first { $0.kind == .anchors })
        #expect(anchors.value == 50)
        // tasks 100, anchors 50, load 100 → (35×100 + 25×50 + 20×100) ÷ 80 = 84.4
        #expect(try score(snapshot(w)) == 84)
    }

    @Test func aLateCorrectionCountsAsAttendedAndAClosedPendingAnchorCountsAsMissed() throws {
        let w = try world()
        active(w, days: 1...7)
        for day in 1...7 {
            _ = anchor(w, day: day, status: .attended, hour: 5)             // incl. "marked done after all"
            _ = anchor(w, day: day, status: .pending, hour: 6)              // window closed, never tapped: reads as missed
        }
        #expect(try snapshot(w).parts.first { $0.kind == .anchors }?.value == 50)
    }

    @Test func daysWithNoDecidedAnchorsAreLeftOutAndNoAnchorsAtAllMeansNoAnchorsPart() throws {
        let w = try world()
        active(w, days: 1...7)
        _ = anchor(w, day: 1, status: .attended)                              // only one day has any
        #expect(try snapshot(w).parts.first { $0.kind == .anchors }?.value == 100)
        let none = try world()
        active(none, days: 1...7)
        #expect(try snapshot(none).parts.contains { $0.kind == .anchors } == false)
    }

    // MARK: Habits

    private func habit(_ w: TaskWorld, kind: HabitKind = .binary, target: Int = 1, perWeek: Int = 0) -> HabitTimeWindow {
        let h = Habit(title: "H"); h.habitKind = kind; h.targetPerWeek = perWeek; h.createdAt = w.at(1, 0); w.context.insert(h)
        let win = HabitTimeWindow(); win.target = target; w.context.insert(win); win.habit = h
        return win
    }

    private func log(_ w: TaskWorld, _ window: HabitTimeWindow, day: Int, amount: Int) {
        let e = HabitEntry(); e.date = w.d(day).storedDate; e.amount = amount; e.target = window.target
        w.context.insert(e); e.window = window
    }

    @Test func habitsAreTheMeanDensityOfTheDaysDueWindowsOnActiveDays() throws {
        let w = try world()
        active(w, days: 1...7)
        let water = habit(w, kind: .counted, target: 4)
        log(w, water, day: 1, amount: 4)                                      // 1.0
        log(w, water, day: 2, amount: 2)                                      // 0.5
        log(w, water, day: 3, amount: 1)                                      // 0.25
        // days 4–7: nothing logged: missed, 0
        let habits = try #require(try snapshot(w).parts.first { $0.kind == .habits })
        #expect(abs(habits.value - (1.0 + 0.5 + 0.25) / 7.0 * 100) < 0.01)    // 25
    }

    @Test func pausedAndArchivedHabitsAndInactiveDaysAreNotCounted() throws {
        let w = try world()
        active(w, days: 1...7)
        let paused = habit(w); paused.habit?.pauses = [HabitPause(from: w.d(1), to: nil, reason: .travel)]
        let archived = habit(w); archived.habit?.isArchived = true
        _ = (paused, archived)
        #expect(try snapshot(w).parts.contains { $0.kind == .habits } == false)
        // A habit done on an inactive day (no DayPlan) isn't counted either.
        let other = habit(w)
        log(w, other, day: 10, amount: 1)
        #expect(try snapshot(w).parts.first { $0.kind == .habits }?.value == 0)    // the seven active days: all missed
    }

    @Test func aWeeklyTargetHabitCountsOncePerFullWeekInTheWindow() throws {
        let w = try world()
        active(w, days: 1...14)
        let run = habit(w, perWeek: 2)
        log(w, run, day: 5, amount: 1)                                        // Mon 5–Sun 11 is the one full Monday-first week: 1 of 2
        let habits = try #require(try snapshot(w).parts.first { $0.kind == .habits })
        #expect(habits.value == 50)
    }

    // MARK: Sparkline and trend

    @Test func theSparklineIsFourteenDaysEachOverItsOwnTrailingFourteenShownFromSevenActiveDays() throws {
        let w = try world()
        active(w, days: 1...14)
        let s = try snapshot(w)
        #expect(s.sparkline.count == 14)
        #expect(s.sparkline.first?.day == d(1))
        #expect(s.sparkline.last?.day == d(14))
        #expect(s.sparkline.first { $0.day == d(6) }?.score == nil)           // six active days by the 6th
        #expect(s.sparkline.first { $0.day == d(7) }?.score != nil)           // seven by the 7th
        #expect(s.sparkline.last?.score == score(s))
    }

    @Test func aPointOnlyLooksBackFourteenDays() throws {
        let w = try world()
        active(w, days: 1...7, completion: 0.2)                               // old, poor days
        active(w, days: 8...14, completion: 1.0)                              // recent, good days
        let s = try snapshot(w)
        let early = try #require(s.sparkline.first { $0.day == d(7) }?.score)
        let late = try #require(s.sparkline.first { $0.day == d(14) }?.score)
        #expect(late > early)
        #expect(abs(Double(late) - Double(score(s) ?? 0)) < 0.5)
    }

    @Test func theTrendComparesWithTheScoreFourteenDaysEarlier() throws {
        let w = try world()
        active(w, days: 17...30, month: 9, completion: 0.5)                    // the previous window (17–30 Sep)
        active(w, days: 1...14, completion: 0.9)
        guard case .active(_, let better) = try snapshot(w).state else { Issue.record("expected an active score"); return }
        #expect(better == .steadier)

        let flat = try world()
        active(flat, days: 17...30, month: 9, completion: 0.9)
        active(flat, days: 1...14, completion: 0.9)
        guard case .active(_, let same) = try snapshot(flat).state else { Issue.record("expected an active score"); return }
        #expect(same == .aboutTheSame)

        let worse = try world()
        active(worse, days: 17...30, month: 9, completion: 0.95)
        active(worse, days: 1...14, completion: 0.4)
        guard case .active(_, let heavier) = try snapshot(worse).state else { Issue.record("expected an active score"); return }
        #expect(heavier == .heavier)
    }

    @Test func aSmallMovementIsStillAboutTheSame() throws {
        let w = try world()
        active(w, days: 17...30, month: 9, completion: 0.85)                   // scores 90
        active(w, days: 1...14, completion: 0.9)                               // scores 94: four points is not a change
        guard case .active(_, let trend) = try snapshot(w).state else { Issue.record("expected an active score"); return }
        #expect(trend == .aboutTheSame)
    }

    @Test func noTrendWithoutAScoreFromTheEarlierWindow() throws {
        let w = try world()
        active(w, days: 1...14)
        guard case .active(_, let trend) = try snapshot(w).state else { Issue.record("expected an active score"); return }
        #expect(trend == nil)
    }
}

// MARK: The counts behind the read

extension WellbeingTests {

    @Test func theCountsAreTasksFinishedOverTasksThatHadToBeFinishedOnActiveDays() throws {
        let w = try world()
        for day in 8...14 { plan(w, d(day), completion: 2.0 / 3.0, basis: 3) }       // 2 of 3, seven days
        plan(w, d(7), completion: 0, basis: 0)                                          // nothing to finish: no count
        plan(w, d(15), completion: 1, basis: 9)                                          // today: not counted
        let s = try snapshot(w)
        #expect(s.tasksDone == 14 && s.tasksToFinish == 21)
    }

    @Test func aHalfFinishedDayRoundsUpToTheNearestTask() throws {
        let w = try world()
        for day in 8...14 { plan(w, d(day), completion: 0.5, basis: 3) }               // 1.5 of 3 a day → 2
        let s = try snapshot(w)
        #expect(s.tasksDone == 14 && s.tasksToFinish == 21)
    }

    @Test func anchorCountsLeaveOutSkippedDelegatedAndDaysOutsideTheWindow() throws {
        let w = try world()
        active(w, days: 8...14)
        _ = anchor(w, day: 8, status: .attended)
        _ = anchor(w, day: 9, status: .attended)
        _ = anchor(w, day: 9, status: .missed)
        _ = anchor(w, day: 10, status: .skipped)
        _ = anchor(w, day: 11, status: .delegated)
        _ = anchor(w, day: 3, status: .attended)                                        // not an active day in the window
        let s = try snapshot(w)
        #expect(s.anchorsAttended == 2 && s.anchorsDecided == 3)
    }

    @Test func whileGatheringDataTheCountsAreZero() throws {
        let w = try world()
        active(w, days: 10...13)
        _ = anchor(w, day: 10, status: .attended)
        let s = try snapshot(w)
        #expect(s.tasksDone == 0 && s.tasksToFinish == 0 && s.anchorsAttended == 0 && s.anchorsDecided == 0)
    }
}
