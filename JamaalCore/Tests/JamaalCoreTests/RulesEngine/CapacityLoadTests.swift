import Foundation
import Testing
@testable import JamaalCore

/// Module 7, the energy budget (docs/architecture/rules-engine.md): the user's level gives a
/// minute budget for *tasks only*; load is planned minutes against it.
struct CapacityLoadTests {

    @Test(arguments: [
        // normal day, expected low, medium, high  (low = 2/3, high = 4/3, each rounded to 5 min)
        (180, 120, 180, 240),
        (205, 135, 205, 275),   // 136.7 -> 135, 273.3 -> 275
        (30, 20, 30, 40),
        (360, 240, 360, 480),
        (200, 135, 200, 265),   // 133.3 -> 135, 266.7 -> 265
    ])
    func budgetsRoundLowAndHighToFiveMinutes(normal: Int, low: Int, medium: Int, high: Int) {
        #expect(CapacityLoad.budgetMinutes(for: .low, mediumDayMinutes: normal) == low)
        #expect(CapacityLoad.budgetMinutes(for: .medium, mediumDayMinutes: normal) == medium)
        #expect(CapacityLoad.budgetMinutes(for: .high, mediumDayMinutes: normal) == high)
    }

    @Test func anUnknownLevelBudgetsAsMedium() {
        #expect(CapacityLoad.budgetMinutes(for: .unknown, mediumDayMinutes: 180) == 180)
    }

    @Test(arguments: [
        (0, 180, 0), (90, 180, 50), (135, 180, 75), (180, 180, 100), (270, 180, 150), (1, 180, 1),
    ])
    func loadScoreIsPlannedOverBudgetAsAPercentage(planned: Int, budget: Int, score: Int) {
        #expect(CapacityLoad.loadScore(plannedMinutes: planned, budgetMinutes: budget) == score)
    }

    @Test func aZeroBudgetNeverDividesByZero() {
        #expect(CapacityLoad.loadScore(plannedMinutes: 60, budgetMinutes: 0) == 0)
    }

    @Test(arguments: [
        (0, LoadState.light), (69, .light), (70, .balanced), (89, .balanced), (90, .full),
        (109, .full), (110, .overloaded), (140, .overloaded), (141, .exhausting), (300, .exhausting),
    ])
    func loadStatesFollowTheDocumentedThresholds(score: Int, state: LoadState) {
        #expect(LoadState(score: score) == state)
    }

    @Test func overloadedOrWorseIsWhatWasOverloadedMeans() {
        #expect(!LoadState.full.isOverloaded)
        #expect(LoadState.overloaded.isOverloaded)
        #expect(LoadState.exhausting.isOverloaded)
    }

    // MARK: Weekday defaults

    @Test func weekendsDefaultToLowAndOtherDaysToMedium() {
        let settings = UserSettings()
        #expect(settings.defaultLevel(forISOWeekday: 1) == .medium)
        #expect(settings.defaultLevel(forISOWeekday: 5) == .medium)
        #expect(settings.defaultLevel(forISOWeekday: 6) == .low)
        #expect(settings.defaultLevel(forISOWeekday: 7) == .low)
    }

    @Test func aCustomWeekdayMapIsRead() {
        let settings = UserSettings()
        settings.weekdayLevels = #"{"2":"high","6":"medium"}"#
        #expect(settings.defaultLevel(forISOWeekday: 2) == .high)
        #expect(settings.defaultLevel(forISOWeekday: 6) == .medium)
        #expect(settings.defaultLevel(forISOWeekday: 7) == .medium)   // not listed
    }

    @Test(arguments: ["", "not json", "[]", #"{"1":"enormous"}"#])
    func anUnreadableMapFallsBackToMedium(json: String) {
        let settings = UserSettings()
        settings.weekdayLevels = json
        #expect(settings.defaultLevel(forISOWeekday: 1) == .medium)
    }
}
