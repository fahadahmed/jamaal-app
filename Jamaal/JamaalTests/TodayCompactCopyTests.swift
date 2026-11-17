//
//  TodayCompactCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct TodayCompactCopyTests {
    @Test func theCollapsedAnchorsLineNamesTheNextOneAndHowTheDayIsGoing() {
        #expect(TodayCopy.anchorsLine(attended: 3, counting: 7, next: .init(title: "Asr", isOpen: true, start: "4:21 pm", end: "5:58 pm"))
                == "Asr · until 5:58 pm · 3 of 7")
        #expect(TodayCopy.anchorsLine(attended: 3, counting: 7, next: .init(title: "Isha", isOpen: false, start: "8:52 pm", end: "11:00 pm"))
                == "Isha · from 8:52 pm · 3 of 7")
    }

    @Test func whenNothingIsLeftItSaysSoCalmly() {
        #expect(TodayCopy.anchorsLine(attended: 6, counting: 7, next: nil) == "Done for today · 6 of 7")
        #expect(TodayCopy.anchorsLine(attended: 0, counting: 0, next: nil) == "None today")
    }

    @Test func theAnchorsLineNeverShoutsOrScolds() {
        let lines = [
            TodayCopy.anchorsLine(attended: 0, counting: 5, next: nil),
            TodayCopy.anchorsLine(attended: 1, counting: 5, next: .init(title: "Fajr", isOpen: true, start: "5:00 am", end: "6:10 am")),
        ]
        #expect(!lines.contains { $0.contains("!") || $0.lowercased().contains("missed") })
    }

    @Test func theCapacityRowNamesTheLevelBeforeTheFigures() {
        #expect(TodayCopy.levelName(.low) == "Low")
        #expect(TodayCopy.levelName(.medium) == "Medium")
        #expect(TodayCopy.levelName(.high) == "High")
        #expect(TodayCopy.levelName(.unknown) == "Medium")
        #expect(TodayCopy.capacityRow(level: .medium, plannedMinutes: 135, budgetMinutes: 180, wholeDay: false) == "Medium · 2h 15m of 3h")
        #expect(TodayCopy.capacityRow(level: .low, plannedMinutes: 135, budgetMinutes: 120, wholeDay: true) == "Low · 2h 15m of 2h · whole day")
    }

    @Test func theSectionHeadersExplainTheirButton() {
        #expect(TodayCopy.sectionHint(isOpen: false) == "Shows them")
        #expect(TodayCopy.sectionHint(isOpen: true) == "Hides them")
    }
}
