import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Density states (docs/schema/habit.md): each due day is one cell shaded by how much was done.
/// Never a streak; a missed day is one unfilled cell. Today is 15 Oct 2026 (a Thursday) unless
/// a test says otherwise.
@MainActor
struct HabitDensityTests {

    private func state(_ w: HabitWorld, _ window: HabitTimeWindow, _ day: Int, today: Int = 15, engaged: Set<Int> = []) -> DensityState {
        HabitDensity.state(of: window, on: w.d(day), context: w.ctx(today: today, engaged: engaged))
    }

    // MARK: Binary

    @Test func aBinaryDayIsCompleteMissedOrStillOpen() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Read")
        w.entry(window, day: 10, amount: 1)
        #expect(state(w, window, 10) == .complete)
        #expect(state(w, window, 11) == .missed)        // a due day with nothing logged
        #expect(state(w, window, 15) == .empty)         // today is unresolved
        #expect(state(w, window, 16) == .empty)         // the future
    }

    @Test func anUnTickedDayIsMissedLikeAnEmptyOne() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Read")
        w.entry(window, day: 10, amount: 0)
        #expect(state(w, window, 10) == .missed)
    }

    @Test func daysBeforeTheHabitExistedAreEmptyNotMissed() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Read", createdOn: 12)
        #expect(state(w, window, 11) == .empty)
        #expect(state(w, window, 12) == .missed)
    }

    @Test func unscheduledDaysNeitherFillNorCountAgainstTheHabit() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Gym", days: "1,3,5")                       // Mon, Wed, Fri
        #expect(state(w, window, 12) == .missed)                              // Mon 12 Oct
        #expect(state(w, window, 13) == .empty)                               // Tue
        w.entry(window, day: 13, amount: 1)                                    // done on an unscheduled day anyway
        #expect(state(w, window, 13) == .complete)
    }

    @Test func pausedDaysAreEmptyNotMissed() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Read")
        habit.pauses = [HabitPause(from: w.d(10), to: w.d(12), reason: .travel)]
        #expect(state(w, window, 9) == .missed)
        #expect(state(w, window, 10) == .empty)
        #expect(state(w, window, 12) == .empty)
        #expect(state(w, window, 13) == .missed)
    }

    // MARK: Counted and timed shade in steps

    @Test(arguments: [
        (0, DensityState.missed), (1, .partialLow), (3, .partialLow), (4, .partialHigh),   // 3/8 = 38%, 4/8 = 50%
        (7, .partialHigh), (8, .complete), (12, .complete),                                  // beyond the target doesn't over-fill
    ])
    func aCountedDayShadesByHowMuchWasDone(amount: Int, expected: DensityState) throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Water", kind: .counted, target: 8)
        if amount > 0 { w.entry(window, day: 10, amount: amount) }
        #expect(state(w, window, 10) == expected)
    }

    @Test(arguments: [(7, DensityState.partialLow), (8, .partialHigh), (14, .partialHigh), (15, .complete), (40, .complete)])
    func aTimedDayShadesByMinutesAgainstTheTarget(minutes: Int, expected: DensityState) throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Qur'an", kind: .timed, target: 15)
        w.entry(window, day: 10, amount: minutes)
        #expect(state(w, window, 10) == expected)
    }

    @Test func anEntryKeepsTheTargetItWasLoggedAgainst() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Water", kind: .counted, target: 8)
        w.entry(window, day: 10, amount: 3, target: 3)                         // the target was 3 then
        window.target = 8                                                      // changed later: affects the future only
        #expect(state(w, window, 10) == .complete)
    }

    // MARK: Avoid

    @Test func anAvoidDayIsCompleteOnlyWithinTheAllowanceAndEngagement() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("No sugar", kind: .avoid, target: 1)          // one slip allowed
        w.entry(window, day: 10, amount: 1)                                      // a slip, within the allowance
        #expect(state(w, window, 10, engaged: [10]) == .complete)
        #expect(state(w, window, 10, engaged: []) == .empty)                     // silence is never success
        w.entry(window, day: 11, amount: 2)                                      // beyond the allowance
        #expect(state(w, window, 11, engaged: [11]) == .missed)
        #expect(state(w, window, 12, engaged: []) == .empty)                     // nothing logged, app untouched
    }

    @Test func heldTodayIsItsOwnEngagement() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("No sugar", kind: .avoid, target: 0)
        w.entry(window, day: 10, amount: 0, completed: true)
        #expect(state(w, window, 10, engaged: []) == .complete)
    }

    @Test func todayStaysUnresolvedForAvoidHabitsEvenAfterASlip() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("No sugar", kind: .avoid, target: 0)
        w.entry(window, day: 15, amount: 2, completed: true)
        #expect(state(w, window, 15, engaged: [15]) == .empty)
    }

    // MARK: Weekly-target habits never miss

    @Test func aWeeklyTargetHabitHasOnlyFilledAndEmptyDays() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Run", kind: .timed, target: 30, perWeek: 3)
        w.entry(window, day: 7, amount: 30)
        w.entry(window, day: 8, amount: 10)
        #expect(state(w, window, 7) == .complete)
        #expect(state(w, window, 8) == .partialLow)
        #expect(state(w, window, 9) == .empty)                                   // never missed
        #expect(state(w, window, 14) == .empty)
    }

    // MARK: The grid

    @Test func theGridRunsOldestToNewestEndingToday() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Read")
        w.entry(window, day: 14, amount: 1)
        let grid = HabitDensity.grid(of: window, days: 3, context: w.ctx(today: 15))
        #expect(grid.map(\.day) == [w.d(13), w.d(14), w.d(15)])
        #expect(grid.map(\.state) == [.missed, .complete, .empty])
    }
}

/// The plain-language read's signal and the weekly progress.
@MainActor
struct HabitReadTests {

    @Test func countsResolvedDaysOverTheLastThreeWeeksLeavingOutPausedAndUnscheduled() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Read", createdOn: 1)
        // 15 Oct is today. Window: 24 Sep – 15 Oct, but the habit only exists from 1 Oct: 1–14 Oct are 14 days.
        for day in [2, 3, 4, 5, 6] { w.entry(window, day: day, amount: 1) }       // 5 done
        habit.pauses = [HabitPause(from: w.d(8), to: w.d(10), reason: .travel)]     // 3 paused days
        let read = HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15))
        #expect(read.completed == 5)
        #expect(read.missed == 14 - 5 - 3)                                           // 6
        #expect(read.due == 11)
        #expect(read.windowDays == 21)
    }

    @Test func todayCountsOnlyOnceItIsFinished() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Read", createdOn: 14)
        #expect(HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15)).due == 1)   // 14 Oct missed; today open
        w.entry(window, day: 15, amount: 1)
        let read = HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15))
        #expect(read.due == 2)
        #expect(read.completed == 1)
    }

    @Test func aPartialTodayIsNotCountedUntilItIsFinished() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Water", kind: .counted, target: 8, createdOn: 14)
        w.entry(window, day: 15, amount: 3)                                           // 3 of 8 so far today
        let read = HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15))
        #expect(read.partial == 0)
        #expect(read.due == 1)                                                          // only 14 Oct, which was missed
    }

    @Test func suggestsALighterCadenceWhenMoreThanHalfAreMissedOverEnoughDays() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Read", createdOn: 1)
        for day in [2, 3, 4] { w.entry(window, day: day, amount: 1) }               // 3 of 14 done
        let read = HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15))
        #expect(read.suggestsLighterCadence)
    }

    @Test func noSuggestionBelowHalfMissedOrWithTooFewDays() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Read", createdOn: 1)
        for day in 2...10 { w.entry(window, day: day, amount: 1) }                  // 9 of 14 done: 5 missed
        #expect(!HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15)).suggestsLighterCadence)

        let (young, _) = w.habit("New", createdOn: 12)                                // 3 resolved days, all missed
        #expect(!HabitDensity.read(of: young, windowDays: 21, context: w.ctx(today: 15)).suggestsLighterCadence)
    }

    @Test func partialDaysAreCountedSeparately() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Water", kind: .counted, target: 8, createdOn: 12)
        w.entry(window, day: 12, amount: 8)
        w.entry(window, day: 13, amount: 3)
        let read = HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15))
        #expect(read.completed == 1)
        #expect(read.partial == 1)
        #expect(read.missed == 1)                                                     // 14 Oct
    }

    @Test func avoidHabitsCountOnlyResolvedDays() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("No sugar", kind: .avoid, target: 1, createdOn: 11)
        w.entry(window, day: 11, amount: 0, completed: true)       // held
        w.entry(window, day: 12, amount: 3)                          // over the allowance
        // 13 and 14: nothing logged and the app untouched: silent days are not counted either way.
        let read = HabitDensity.read(of: habit, windowDays: 21, context: w.ctx(today: 15))
        #expect(read.completed == 1)
        #expect(read.missed == 1)
        #expect(read.due == 2)
    }

    // MARK: Weekly progress (the week starts on the calendar's first weekday)

    @Test func weeklyProgressCountsDaysThatMetTheirOwnTarget() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Run", kind: .timed, target: 30, perWeek: 3, createdOn: 1)
        w.entry(window, day: 12, amount: 30)        // Mon
        w.entry(window, day: 13, amount: 12)        // Tue, partial: doesn't count
        w.entry(window, day: 14, amount: 45)        // Wed
        let progress = try #require(HabitSchedule.weeklyProgress(of: habit, on: w.d(15), context: w.ctx(today: 15)))
        #expect(progress.done == 2)
        #expect(progress.target == 3)
        #expect(!progress.isMet)
    }

    @Test func theWeekStartFollowsTheFirstWeekday() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Run", perWeek: 2, createdOn: 1)
        w.entry(window, day: 11, amount: 1)         // Sunday 11 Oct
        let monday = try #require(HabitSchedule.weeklyProgress(of: habit, on: w.d(15), context: w.ctx(today: 15, firstWeekday: 1)))
        #expect(monday.done == 0)                    // the Monday-first week is 12–18 Oct
        let sunday = try #require(HabitSchedule.weeklyProgress(of: habit, on: w.d(15), context: w.ctx(today: 15, firstWeekday: 7)))
        #expect(sunday.done == 1)                    // the Sunday-first week is 11–17 Oct
    }

    @Test func aFixedDayHabitHasNoWeeklyProgress() throws {
        let w = try HabitWorld()
        let (habit, _) = w.habit("Read")
        #expect(HabitSchedule.weeklyProgress(of: habit, on: w.d(15), context: w.ctx(today: 15)) == nil)
    }
}
