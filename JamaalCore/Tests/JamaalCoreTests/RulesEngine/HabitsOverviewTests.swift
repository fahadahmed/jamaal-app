import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The Habits tab (docs/journeys/walkthroughs/05-habits.md): groups with a 14-day aggregate, ungrouped habits,
/// what is paused, what is archived, and the rules for pausing, resuming and correcting a past day. Thu 15 Oct 2026.
@MainActor
struct HabitsOverviewTests {

    private func read(_ world: HabitWorld, today: Int = 15) throws -> HabitsOverview {
        try HabitsOverview.read(in: world.context, now: world.instant(today, 9), boundary: world.boundary)
    }

    // MARK: Overview

    @Test func ungroupedHabitsListInTheOrderTheyWereMadeThenByTitle() throws {
        let world = try HabitWorld()
        world.habit("Water", kind: .counted, target: 8, createdOn: 3)
        world.habit("Run", createdOn: 1)
        world.habit("Floss", createdOn: 1)
        #expect(try read(world).ungrouped.map(\.habit.title) == ["Floss", "Run", "Water"])
    }

    @Test func aHabitSummaryCarriesTodaysAmountsPerWindow() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit("Water", kind: .counted, target: 8)
        world.entry(w, day: 15, amount: 3)
        let summary = try #require(try read(world).ungrouped.first)
        let today = try #require(summary.windows.first)
        #expect(today.amount == 3)
        #expect(today.target == 8)
        #expect(!today.isDone)
        #expect(!summary.isPaused)
    }

    @Test func aWeeklyTargetHabitCarriesItsWeekSoFar() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit("Run", perWeek: 3)
        world.entry(w, day: 12, amount: 1)
        world.entry(w, day: 14, amount: 1)
        let summary = try #require(try read(world).ungrouped.first)
        #expect(summary.weekly == WeeklyProgress(done: 2, target: 3))
    }

    @Test func aPausedHabitIsStillListedAndSaysWhyAndUntilWhen() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Reading before bed")
        h.pauses = [HabitPause(from: world.d(14), to: world.d(19), reason: .travel)]
        let summary = try #require(try read(world).ungrouped.first)
        #expect(summary.isPaused)
        #expect(summary.pause?.reasonKind == .travel)
        #expect(summary.pause?.to == world.d(19))
    }

    @Test func aPauseThatEndedOrHasNotStartedIsNotShownAsPaused() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Reading")
        h.pauses = [HabitPause(from: world.d(1), to: world.d(5), reason: .other), HabitPause(from: world.d(20), to: nil, reason: .other)]
        #expect(try read(world).ungrouped.first?.isPaused == false)
    }

    @Test func groupsCollectTheirHabitsWithTodaysCountAndAFourteenDayAggregate() throws {
        let world = try HabitWorld()
        let g = HabitGroup(); g.title = "Morning"; world.context.insert(g)
        let (a, wa) = world.habit("Stretch"); a.group = g
        let (b, wb) = world.habit("Vitamin D"); b.group = g
        let (c, _) = world.habit("Make the bed"); c.group = g
        world.entry(wa, day: 15, amount: 1)
        world.entry(wb, day: 15, amount: 1)
        let overview = try read(world)
        #expect(overview.ungrouped.isEmpty)
        let group = try #require(overview.groups.first)
        #expect(group.habits.map(\.habit.title).sorted() == ["Make the bed", "Stretch", "Vitamin D"])
        #expect(group.doneToday == 2)
        #expect(group.dueToday == 3)
        #expect(group.grid.count == 14)
        #expect(group.grid.last?.day == world.d(15))
    }

    @Test func theAggregateIsCompleteWhenEveryWindowWasAndMissedWhenNoneWere() throws {
        let world = try HabitWorld()
        let g = HabitGroup(); g.title = "Morning"; world.context.insert(g)
        let (a, wa) = world.habit("A"); a.group = g
        let (b, wb) = world.habit("B"); b.group = g
        world.entry(wa, day: 13, amount: 1); world.entry(wb, day: 13, amount: 1)      // both
        world.entry(wa, day: 12, amount: 1)                                            // one of two
        let grid = try #require(try read(world).groups.first).grid
        func state(_ day: Int) -> DensityState? { grid.first { $0.day == world.d(day) }?.state }
        #expect(state(13) == .complete)
        #expect(state(12) == .partialHigh)                                              // half
        #expect(state(11) == .missed)                                                   // neither
        #expect(state(15) == .empty)                                                    // today is still open
    }

    @Test func archivedHabitsAreListedApartAndKeepTheirHistory() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Cold shower"); h.isArchived = true
        world.habit("Shown")
        let overview = try read(world)
        #expect(overview.ungrouped.map(\.habit.title) == ["Shown"])
        #expect(overview.archived.map(\.title) == ["Cold shower"])
    }

    @Test func anArchivedGroupsHabitsAreStillOrdinaryHabits() throws {
        let world = try HabitWorld()
        let g = HabitGroup(); g.title = "Old"; g.isArchived = true; world.context.insert(g)
        let (h, _) = world.habit("Stretch"); h.group = g
        let overview = try read(world)
        #expect(overview.groups.isEmpty)
        #expect(overview.ungrouped.map(\.habit.title) == ["Stretch"])
    }

    @Test func anEmptyStoreHasNothingToShow() throws {
        let world = try HabitWorld()
        let o = try read(world)
        #expect(o.groups.isEmpty && o.ungrouped.isEmpty && o.archived.isEmpty)
    }

    // MARK: Pause, resume, archive

    @Test func pausingRecordsTheRangeAndReason() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(15), until: world.d(19), reason: .illness)
        #expect(h.pauses == [HabitPause(from: world.d(15), to: world.d(19), reason: .illness)])
        #expect(h.isPaused(on: world.d(17)))
        #expect(!h.isPaused(on: world.d(20)))
    }

    @Test func aPauseWithNoEndRunsUntilResumed() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(15), until: nil, reason: .travel)
        #expect(h.isPaused(on: world.d(28)))
        #expect(h.pauses.first?.to == nil)
    }

    @Test func anEndBeforeTheStartIsRefused() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        #expect(throws: HabitPauseError.endsBeforeItStarts) {
            try HabitPauses.pause(h, from: world.d(15), until: world.d(14), reason: .other)
        }
        #expect(h.pauses.isEmpty)
    }

    @Test func aNewPauseMergesWithAnOverlappingOne() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(15), until: world.d(19), reason: .travel)
        try HabitPauses.pause(h, from: world.d(18), until: world.d(24), reason: .travel)
        #expect(h.pauses.count == 1)
        #expect(h.pauses.first?.from == world.d(15))
        #expect(h.pauses.first?.to == world.d(24))
    }

    @Test func resumingEndsThePauseTheDayBefore() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(10), until: nil, reason: .illness)
        HabitPauses.resume(h, on: world.d(15))
        #expect(h.isPaused(on: world.d(14)))
        #expect(!h.isPaused(on: world.d(15)))
        #expect(h.pauses.first?.to == world.d(14))
    }

    @Test func resumingAPauseThatStartsTodayOrLaterRemovesIt() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(15), until: world.d(20), reason: .other)
        HabitPauses.resume(h, on: world.d(15))
        #expect(h.pauses.isEmpty)
    }

    @Test func resumingAHabitThatIsNotPausedChangesNothing() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(1), until: world.d(5), reason: .other)
        HabitPauses.resume(h, on: world.d(15))
        #expect(h.pauses.count == 1)
    }

    @Test func theActivePauseIsTheOneCoveringToday() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(1), until: world.d(5), reason: .travel)
        try HabitPauses.pause(h, from: world.d(14), until: world.d(18), reason: .illness)
        #expect(HabitPauses.active(h, on: world.d(15))?.reasonKind == .illness)
        #expect(HabitPauses.active(h, on: world.d(10)) == nil)
    }

    // MARK: Correcting a past day

    @Test func theLastFourteenDaysCanBeCorrectedAndOlderOnesCannot() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run", createdOn: 1)
        let today = world.d(15)
        #expect(HabitLogging.canCorrect(h, day: today, today: today, boundary: world.boundary))
        #expect(HabitLogging.canCorrect(h, day: world.d(2), today: today, boundary: world.boundary))         // 13 days back
        #expect(!HabitLogging.canCorrect(h, day: world.d(1), today: today, boundary: world.boundary))        // 14 days back
        #expect(!HabitLogging.canCorrect(h, day: world.d(16), today: today, boundary: world.boundary))       // the future
    }

    @Test func aDayBeforeTheHabitExistedOrDuringAPauseCannotBeCorrected() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run", createdOn: 10)
        try HabitPauses.pause(h, from: world.d(12), until: world.d(13), reason: .travel)
        let today = world.d(15)
        #expect(!HabitLogging.canCorrect(h, day: world.d(9), today: today, boundary: world.boundary))
        #expect(!HabitLogging.canCorrect(h, day: world.d(12), today: today, boundary: world.boundary))
        #expect(HabitLogging.canCorrect(h, day: world.d(14), today: today, boundary: world.boundary))
    }

    @Test func theOlderHabitComesFirstEvenWhenItsTitleSortsLater() throws {
        let world = try HabitWorld()
        world.habit("Water", createdOn: 1)
        world.habit("Apple", createdOn: 3)
        #expect(try read(world).ungrouped.map(\.habit.title) == ["Water", "Apple"])
    }

    @Test func aShorterPauseInsideALongerOneKeepsTheLongerEnd() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(15), until: world.d(24), reason: .travel)
        try HabitPauses.pause(h, from: world.d(16), until: world.d(18), reason: .travel)
        #expect(h.pauses.count == 1)
        #expect(h.pauses.first?.to == world.d(24))
    }

    @Test func anOpenEndedPauseStaysOpenWhenMergedWithAClosedOne() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(15), until: world.d(20), reason: .travel)
        try HabitPauses.pause(h, from: world.d(18), until: nil, reason: .travel)
        #expect(h.pauses.count == 1)
        #expect(h.pauses.first?.to == nil)
    }

    @Test func pausesStayInDateOrder() throws {
        let world = try HabitWorld()
        let (h, _) = world.habit("Run")
        try HabitPauses.pause(h, from: world.d(20), until: world.d(22), reason: .travel)
        try HabitPauses.pause(h, from: world.d(2), until: world.d(4), reason: .illness)
        #expect(h.pauses.map(\.from) == [world.d(2), world.d(20)])
    }

    @Test func aPausedHabitIsNotDueInItsGroupToday() throws {
        let world = try HabitWorld()
        let g = HabitGroup(); g.title = "Morning"; world.context.insert(g)
        let (a, _) = world.habit("Stretch"); a.group = g
        let (b, _) = world.habit("Vitamin D"); b.group = g
        try HabitPauses.pause(b, from: world.d(14), until: world.d(20), reason: .travel)
        let group = try #require(try read(world).groups.first)
        #expect(group.dueToday == 1)
        #expect(group.habits.count == 2)                                   // still listed
    }

    @Test func anAvoidHabitIsDoneWhenHeldNotWhenItHasNoSlips() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit("No sugar", kind: .avoid, target: 1)
        #expect(try read(world).ungrouped.first?.windows.first?.isDone == false)
        let e = world.entry(w, day: 15, amount: 0, target: 1)
        #expect(try read(world).ungrouped.first?.windows.first?.isDone == false)    // silence isn't success
        e.completedAt = world.instant(15, 20)
        #expect(try read(world).ungrouped.first?.windows.first?.isDone == true)
    }
}
