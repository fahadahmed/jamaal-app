//
//  ComingUpCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct ComingUpCopyTests {
    @Test func theTodayRowCountsTheNextFourteenDaysAndStaysWhenThereAreNone() {
        #expect(ComingUpCopy.rowTitle(count: 6) == "Coming up · 6 next 14 days")
        #expect(ComingUpCopy.rowTitle(count: 1) == "Coming up · 1 next 14 days")
        #expect(ComingUpCopy.rowTitle(count: 0) == "Coming up · nothing scheduled")
    }

    @Test func eachDaySaysHowFarAheadItIs() {
        #expect(ComingUpCopy.howFar(daysAhead: 1) == "Tomorrow")
        #expect(ComingUpCopy.howFar(daysAhead: 2) == "In 2 days")
        #expect(ComingUpCopy.howFar(daysAhead: 6) == "In 6 days")
        #expect(ComingUpCopy.howFar(daysAhead: 7) == "Next week")
        #expect(ComingUpCopy.howFar(daysAhead: 13) == "Next week")
        #expect(ComingUpCopy.howFar(daysAhead: 14) == "In 2 weeks")
    }

    @Test func aDayIsNamedByItsWeekdayAndDate() {
        #expect(ComingUpCopy.dayHeading(CalendarDate(year: 2026, month: 10, day: 16)!) == "Fri 16 Oct")
        #expect(ComingUpCopy.dayHeading(CalendarDate(year: 2026, month: 12, day: 1)!) == "Tue 1 Dec")
    }

    @Test func effortReadsInMinutesOrWholeHours() {
        #expect(ComingUpCopy.effort(45) == "45 min")
        #expect(ComingUpCopy.effort(90) == "90 min")
        #expect(ComingUpCopy.effort(60) == "1 h")
        #expect(ComingUpCopy.effort(120) == "2 h")
        #expect(ComingUpCopy.effort(nil) == nil)
    }

    @Test func aOneOffAnchorSaysItsTimeAndWhatItIs() {
        #expect(ComingUpCopy.anchorMeta(time: "10:30") == "10:30 · one-off Anchor")
    }

    @Test func theScreenIsCalmAndSaysNothingCountsYet() {
        #expect(ComingUpCopy.note == "Tasks wait here until you plan their day. Nothing counts toward capacity yet.")
        #expect(ComingUpCopy.laterTitle(count: 3) == "Later · 3")
        #expect(ComingUpCopy.empty.contains("later day"))
        #expect(![ComingUpCopy.note, ComingUpCopy.empty].contains { $0.contains("!") })
    }
}
