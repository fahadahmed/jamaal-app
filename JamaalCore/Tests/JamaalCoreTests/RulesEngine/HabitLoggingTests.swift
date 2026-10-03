import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Logging a habit from Today: a tick, a step, a slip, Held today. Each writes the day's entry (created on
/// the first log, with the window's target as a snapshot) and sets or clears `completedAt` at the target.
@MainActor
struct HabitLoggingTests {

    private func entry(_ w: HabitTimeWindow, _ world: HabitWorld, day: Int = 15) -> HabitEntry? {
        (w.entries ?? []).first { CalendarDate(storedDate: $0.date) == world.d(day) }
    }
    private func log(_ world: HabitWorld, _ action: HabitLogAction, _ w: HabitTimeWindow, day: Int = 15, hour: Int = 9) throws {
        try HabitLogging.apply(action, to: w, on: world.d(day), now: world.instant(day, hour), context: world.context)
    }

    @Test func tickingABinaryHabitCreatesTheEntryAtItsTargetAndCompletesIt() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .binary)
        try log(world, .toggle, w)
        let e = try #require(entry(w, world))
        #expect(e.amount == 1)
        #expect(e.target == 1)
        #expect(e.completedAt == world.instant(15, 9))
    }

    @Test func tickingAgainClearsItAndKeepsTheOneEntry() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .binary)
        try log(world, .toggle, w)
        try log(world, .toggle, w, hour: 10)
        let e = try #require(entry(w, world))
        #expect(e.amount == 0)
        #expect(e.completedAt == nil)
        #expect((w.entries ?? []).count == 1)
    }

    @Test func aCountedHabitStepsUpAndDownAndCompletesAtTheTarget() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .counted, target: 3)
        try log(world, .increment, w)
        try log(world, .increment, w)
        #expect(entry(w, world)?.amount == 2)
        #expect(entry(w, world)?.completedAt == nil)
        try log(world, .increment, w, hour: 11)
        #expect(entry(w, world)?.completedAt == world.instant(15, 11))
        try log(world, .decrement, w, hour: 12)
        #expect(entry(w, world)?.amount == 2)
        #expect(entry(w, world)?.completedAt == nil)                    // below the target again
    }

    @Test func aCountedHabitNeverGoesBelowZero() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .counted, target: 3)
        try log(world, .decrement, w)
        #expect((entry(w, world)?.amount ?? 0) == 0)
    }

    @Test func goingPastTheTargetKeepsTheOriginalCompletionTime() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .counted, target: 1)
        try log(world, .increment, w, hour: 9)
        try log(world, .increment, w, hour: 10)
        #expect(entry(w, world)?.amount == 2)
        #expect(entry(w, world)?.completedAt == world.instant(15, 9))
    }

    @Test func aSlipCountsAndNeverCompletesTheDay() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .avoid, target: 1)
        try log(world, .logSlip, w)
        #expect(entry(w, world)?.amount == 1)
        #expect(entry(w, world)?.completedAt == nil)
        try log(world, .undoSlip, w)
        #expect(entry(w, world)?.amount == 0)
        try log(world, .undoSlip, w)
        #expect(entry(w, world)?.amount == 0)                           // never negative
    }

    @Test func heldTodayIsAnExplicitEngagementAndCanBeTakenBack() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .avoid, target: 1)
        try log(world, .heldToday, w, hour: 20)
        #expect(entry(w, world)?.completedAt == world.instant(15, 20))
        #expect(entry(w, world)?.amount == 0)
        try log(world, .undoHeld, w)
        #expect(entry(w, world)?.completedAt == nil)
    }

    @Test func anActionThatDoesntFitTheKindIsRefusedAndWritesNothing() throws {
        let world = try HabitWorld()
        let (_, binary) = world.habit(kind: .binary)
        let (_, avoid) = world.habit(kind: .avoid)
        let (_, timed) = world.habit(kind: .timed, target: 20)
        #expect(throws: HabitLogError.wrongKind) { try log(world, .increment, binary) }
        #expect(throws: HabitLogError.wrongKind) { try log(world, .toggle, avoid) }
        #expect(throws: HabitLogError.wrongKind) { try log(world, .logSlip, binary) }
        #expect(throws: HabitLogError.wrongKind) { try log(world, .toggle, timed) }       // minutes come from sessions
        #expect((binary.entries ?? []).isEmpty && (avoid.entries ?? []).isEmpty && (timed.entries ?? []).isEmpty)
    }

    @Test func aLaterTargetChangeDoesNotRewriteToday() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .counted, target: 3)
        try log(world, .increment, w)
        w.target = 8
        try log(world, .increment, w)
        #expect(entry(w, world)?.target == 3)                           // snapshot from the first log
    }

    @Test func eachDayHasItsOwnEntry() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .binary)
        try log(world, .toggle, w, day: 14)
        try log(world, .toggle, w, day: 15)
        #expect((w.entries ?? []).count == 2)
    }

    @Test func whenTwoDevicesLeftTwoEntriesTheLargerIsTheOneEdited() throws {
        let world = try HabitWorld()
        let (_, w) = world.habit(kind: .counted, target: 8)
        let small = world.entry(w, day: 15, amount: 1)
        let large = world.entry(w, day: 15, amount: 4)
        try log(world, .increment, w)
        #expect(large.amount == 5)
        #expect(small.amount == 1)
    }
}
