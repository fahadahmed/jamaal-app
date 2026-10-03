//
//  TodayCopyTests.swift
//  JamaalTests
//

import Testing
import JamaalCore
@testable import Jamaal

/// The words and figures Today shows. Calm, plain, never scolding.
struct TodayCopyTests {

    @Test(arguments: [
        (0, "0m"), (5, "5m"), (45, "45m"), (60, "1h"), (135, "2h 15m"), (180, "3h"), (245, "4h 5m"),
    ])
    func durationsReadInHoursAndMinutes(minutes: Int, text: String) {
        #expect(TodayCopy.duration(minutes) == text)
    }

    @Test func theMeterReadsPlannedOfBudget() {
        #expect(TodayCopy.meter(plannedMinutes: 135, budgetMinutes: 180) == "2h 15m of 3h")
        #expect(TodayCopy.meter(plannedMinutes: 0, budgetMinutes: 120) == "0m of 2h")
    }

    @Test func everyLoadStateHasACalmWord() {
        #expect(TodayCopy.stateWord(.light) == "LIGHT")
        #expect(TodayCopy.stateWord(.balanced) == "BALANCED")
        #expect(TodayCopy.stateWord(.full) == "FULL")
        #expect(TodayCopy.stateWord(.overloaded) == "OVER")
        #expect(TodayCopy.stateWord(.exhausting) == "OVER")
    }

    @Test func onlyTheOverloadedStatesAreFlagged() {
        #expect(!TodayCopy.isOver(.full))
        #expect(TodayCopy.isOver(.overloaded))
        #expect(TodayCopy.isOver(.exhausting))
    }

    @Test(arguments: [
        (0, "A clear day", "to begin."), (1, "One thing,", "gently paced."), (2, "Two things,", "gently paced."),
        (4, "Four things,", "gently paced."), (10, "Ten things,", "gently paced."), (13, "13 things,", "gently paced."),
    ])
    func theHeadlineCountsWhatIsLeft(count: Int, first: String, second: String) {
        let headline = TodayCopy.headline(remaining: count)
        #expect(headline.first == first)
        #expect(headline.second == second)
    }

    @Test func sliderLevelsMapToTheirLabelsAndBack() {
        #expect(TodayCopy.levels == [.low, .medium, .high])
        #expect(TodayCopy.label(for: .low) == "LOW")
        #expect(TodayCopy.label(for: .medium) == "MEDIUM")
        #expect(TodayCopy.label(for: .high) == "HIGH")
        #expect(TodayCopy.level(forStep: 0) == .low)
        #expect(TodayCopy.level(forStep: 1) == .medium)
        #expect(TodayCopy.level(forStep: 2) == .high)
        #expect(TodayCopy.level(forStep: 7) == .high)                       // clamped
        #expect(TodayCopy.level(forStep: -1) == .low)
        #expect(TodayCopy.step(for: .high) == 2)
        #expect(TodayCopy.step(for: .unknown) == 1)                         // reads as medium
    }

    @Test func aTaskRowSubtitleJoinsWhatIsKnown() {
        #expect(TodayCopy.taskMeta(deferrals: 0, effortMinutes: 60) == ["60 min"])
        #expect(TodayCopy.taskMeta(deferrals: 2, effortMinutes: 15) == ["Slipped twice", "15 min"])
        #expect(TodayCopy.taskMeta(deferrals: 1, effortMinutes: nil) == ["Slipped once"])
        #expect(TodayCopy.taskMeta(deferrals: 4, effortMinutes: 30) == ["Slipped 4 times", "30 min"])
        #expect(TodayCopy.taskMeta(deferrals: 0, effortMinutes: nil).isEmpty)
        #expect(TodayCopy.taskMeta(deferrals: 0, effortMinutes: 90) == ["90 min"])
    }

    @Test func theHeaderNamesTheLogicalDay() {
        #expect(TodayCopy.headerLabel(CalendarDate(year: 2026, month: 5, day: 12)!) == "TUE 12 MAY")
        #expect(TodayCopy.headerLabel(CalendarDate(year: 2026, month: 10, day: 4)!) == "SUN 4 OCT")
        #expect(TodayCopy.headerLabel(CalendarDate(year: 2026, month: 1, day: 5)!) == "MON 5 JAN")
    }
}
