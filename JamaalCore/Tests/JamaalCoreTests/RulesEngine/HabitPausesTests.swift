import Foundation
import Testing
@testable import JamaalCore

/// `Habit.pausesData` (docs/schema/habit.md, "Pauses"): date ranges when a habit is paused.
@MainActor
struct HabitPausesTests {

    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }

    @Test func readsTheDocumentedShapeIncludingAnOpenEnd() {
        let json = #"[{"from":"2026-10-12","to":"2026-10-19","reason":"travel"},{"from":"2026-11-01","to":null,"reason":"illness"}]"#
        let pauses = HabitPauses.decode(json)
        #expect(pauses.count == 2)
        #expect(pauses[0].from == CalendarDate(year: 2026, month: 10, day: 12))
        #expect(pauses[0].to == CalendarDate(year: 2026, month: 10, day: 19))
        #expect(pauses[0].reasonKind == .travel)
        #expect(pauses[1].to == nil)
    }

    @Test func anUnknownReasonIsKeptAsTheRawString() {
        let pauses = HabitPauses.decode(#"[{"from":"2026-10-12","to":null,"reason":"retreat"}]"#)
        #expect(pauses.first?.reasonKind == .unknown)
        #expect(pauses.first?.reason == "retreat")
        #expect(HabitPauses.decode(HabitPauses.encode(pauses)).first?.reason == "retreat")   // survives a round trip
    }

    @Test(arguments: ["", "[]", "not json", "{}", #"[{"from":"nope"}]"#])
    func anEmptyOrUnreadableValueMeansNoPauses(json: String) {
        #expect(HabitPauses.decode(json).isEmpty)
    }

    @Test func roundTripsThroughTheHabit() {
        let habit = Habit(title: "Run")
        #expect(habit.pauses.isEmpty)
        habit.pauses = [HabitPause(from: d(12), to: d(19), reason: .travel), HabitPause(from: d(25), to: nil, reason: .other)]
        #expect(habit.pauses.count == 2)
        #expect(habit.pauses[1].to == nil)
        #expect(habit.pausesData.contains("2026-10-12"))
    }

    @Test func aPauseCoversItsEndsInclusive() {
        let habit = Habit(title: "Run")
        habit.pauses = [HabitPause(from: d(12), to: d(19), reason: .travel)]
        #expect(!habit.isPaused(on: d(11)))
        #expect(habit.isPaused(on: d(12)))
        #expect(habit.isPaused(on: d(19)))
        #expect(!habit.isPaused(on: d(20)))
    }

    @Test func anOpenEndedPauseRunsUntilTheUserResumes() {
        let habit = Habit(title: "Run")
        habit.pauses = [HabitPause(from: d(12), to: nil, reason: .illness)]
        #expect(!habit.isPaused(on: d(11)))
        #expect(habit.isPaused(on: d(12)))
        #expect(habit.isPaused(on: d(28)))
    }
}
