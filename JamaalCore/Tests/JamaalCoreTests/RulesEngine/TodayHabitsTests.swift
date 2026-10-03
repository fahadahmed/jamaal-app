import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Today's Habits section (docs/journeys/today-list.md, item 4): groups first as pills, then ungrouped habits
/// by window start with all-day last, then title; paused habits hidden; the "N of M" count.
@MainActor
struct TodayHabitsTests {

    private func read(_ world: HabitWorld, today: Int = 15) throws -> TodayHabits {
        try TodayHabits.read(in: world.context, now: world.instant(today, 9), boundary: world.boundary)
    }

    @Test func ungroupedHabitsAreRowsOrderedByWindowStartAllDayLastThenTitle() throws {
        let world = try HabitWorld()
        let (_, allDay) = world.habit("Water", kind: .counted, target: 8)
        let (_, evening) = world.habit("Read", kind: .binary); evening.startMinute = 20 * 60; evening.endMinute = 22 * 60
        let (_, morning) = world.habit("Walk", kind: .binary); morning.startMinute = 7 * 60; morning.endMinute = 9 * 60
        let (_, alsoAllDay) = world.habit("Floss", kind: .binary)
        _ = (allDay, alsoAllDay)
        let t = try read(world)
        #expect(t.rows.map(\.title) == ["Walk", "Read", "Floss", "Water"])
    }

    @Test func groupedHabitsLiveInTheirGroupAsAPillNotAsRows() throws {
        let world = try HabitWorld()
        let g = HabitGroup(); g.title = "Morning"; world.context.insert(g)
        let (h1, _) = world.habit("Stretch")
        let (h2, w2) = world.habit("Vitamins")
        let (_, _) = world.habit("Water", kind: .counted, target: 8)
        h1.group = g; h2.group = g
        world.entry(w2, day: 15, amount: 1)
        let t = try read(world)
        #expect(t.rows.map(\.title) == ["Water"])
        #expect(t.groups.count == 1)
        #expect(t.groups[0].title == "Morning")
        #expect(t.groups[0].rows.map(\.title).sorted() == ["Stretch", "Vitamins"])
        #expect(t.groups[0].done == 1)
        #expect(t.groups[0].total == 2)
    }

    @Test func groupsAreOrderedBySortOrderThenTitle() throws {
        let world = try HabitWorld()
        let a = HabitGroup(); a.title = "Evening"; a.sortOrder = 2
        let b = HabitGroup(); b.title = "Morning"; b.sortOrder = 1
        world.context.insert(a); world.context.insert(b)
        world.habit("One").habit.group = a
        world.habit("Two").habit.group = b
        #expect(try read(world).groups.map(\.title) == ["Morning", "Evening"])
    }

    @Test func pausedAndArchivedHabitsAreHidden() throws {
        let world = try HabitWorld()
        let (paused, _) = world.habit("Paused")
        let (archived, _) = world.habit("Archived")
        world.habit("Shown")
        archived.isArchived = true
        paused.pauses = [HabitPause(from: world.d(10), to: world.d(20), reason: .other)]
        #expect(try read(world).rows.map(\.title) == ["Shown"])
    }

    @Test func aHabitNotScheduledTodayIsNotShown() throws {
        let world = try HabitWorld()
        world.habit("Mondays", days: "1")          // Thu 15 Oct 2026 isn't a Monday
        world.habit("Thursdays", days: "4")
        #expect(try read(world).rows.map(\.title) == ["Thursdays"])
    }

    @Test func aRowCarriesItsKindAmountTargetAndDoneState() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit("Water", kind: .counted, target: 8)
        world.entry(w, day: 15, amount: 3)
        let row = try #require(try read(world).rows.first)
        #expect(row.kind == .counted)
        #expect(row.amount == 3)
        #expect(row.target == 8)
        #expect(!row.isDone)
        world.entry(w, day: 15, amount: 8)          // a second entry (another device): the larger wins
        #expect(try read(world).rows.first?.isDone == true)
    }

    @Test func anAvoidRowCarriesItsAllowanceAndHeldState() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit("Late-night scrolling", kind: .avoid, target: 1)
        let e = world.entry(w, day: 15, amount: 1, target: 1)
        var row = try #require(try read(world).rows.first)
        #expect(row.target == 1)
        #expect(row.amount == 1)
        #expect(!row.isDone)
        e.amount = 0; e.completedAt = world.instant(15, 20)
        row = try #require(try read(world).rows.first)
        #expect(row.isDone)
    }

    @Test func aHabitWithSeveralTimesADayNamesEachWindow() throws {
        let world = try HabitWorld()
        let (h, morning) = world.habit("Medication")
        morning.label = "Morning"; morning.startMinute = 8 * 60; morning.endMinute = 9 * 60
        let evening = HabitTimeWindow(); evening.label = "Evening"; evening.startMinute = 20 * 60; evening.endMinute = 21 * 60
        world.context.insert(evening); evening.habit = h
        #expect(try read(world).rows.map(\.title) == ["Medication · Morning", "Medication · Evening"])
    }

    @Test func theCountIsDoneOutOfDueAcrossGroupsAndRows() throws {
        let world = try HabitWorld()
        let g = HabitGroup(); g.title = "Morning"; world.context.insert(g)
        let (h, w1) = world.habit("Stretch"); h.group = g
        let (_, w2) = world.habit("Water", kind: .counted, target: 2)
        world.habit("Read")
        world.entry(w1, day: 15, amount: 1)
        world.entry(w2, day: 15, amount: 2)
        let t = try read(world)
        #expect(t.total == 3)
        #expect(t.done == 2)
    }

    @Test func aWeeklyTargetHabitIsShownAsDoneOnceTheWeekIsMet() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit("Run", kind: .binary, perWeek: 2)
        world.entry(w, day: 12, amount: 1)           // Mon 12 and Tue 13 (same ISO week; Sunday-first weeks start Sun 11)
        world.entry(w, day: 13, amount: 1)
        let row = try #require(try read(world).rows.first)
        #expect(row.isDone)
    }

    @Test func nothingDueReadsEmpty() throws {
        let world = try HabitWorld()
        let t = try read(world)
        #expect(t.rows.isEmpty && t.groups.isEmpty && t.total == 0 && t.done == 0)
    }

    @Test func anArchivedGroupDoesNotHideItsHabits() throws {
        let world = try HabitWorld()
        let g = HabitGroup(); g.title = "Old"; g.isArchived = true; world.context.insert(g)
        world.habit("Stretch").habit.group = g
        let t = try read(world)
        #expect(t.groups.isEmpty)
        #expect(t.rows.map(\.title) == ["Stretch"])
    }

    @Test func aSingleWindowKeepsTheHabitsOwnTitleEvenWithALabel() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit("Water")
        w.label = "Morning"
        #expect(try read(world).rows.map(\.title) == ["Water"])
    }

    @Test func aTargetBelowOneReadsAsOneForTheKindsThatComplete() throws {
        let world = try HabitWorld()
        world.habit("Odd", kind: .binary, target: 0)
        world.habit("Hold off", kind: .avoid, target: 0)
        let rows = try read(world).rows
        #expect(rows.first { $0.title == "Odd" }?.target == 1)
        #expect(rows.first { $0.title == "Hold off" }?.target == 0)
    }
}
