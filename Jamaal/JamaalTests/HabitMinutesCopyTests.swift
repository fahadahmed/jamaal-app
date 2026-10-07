//
//  HabitMinutesCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct HabitMinutesCopyTests {
    private let today = CalendarDate(year: 2026, month: 10, day: 15)!

    @Test func theSubtitleSaysTheDayAndHowFarTheHabitIs() {
        #expect(HabitMinutesCopy.subtitle(habit: "Qur'an reading", day: today, today: today, done: 6, target: 15) == "Qur'an reading · today, 6 of 15 min so far")
        #expect(HabitMinutesCopy.subtitle(habit: "Read", day: today.addingDays(-1), today: today, done: 0, target: 20) == "Read · yesterday, 0 of 20 min so far")
        let earlier = HabitMinutesCopy.subtitle(habit: "Read", day: today.addingDays(-5), today: today, done: 12, target: 20)
        #expect(earlier.hasPrefix("Read · ") && earlier.contains("10 Oct") && earlier.hasSuffix(", 12 of 20 min so far"))
    }

    @Test func theButtonSaysWhatItAdds() {
        #expect(HabitMinutesCopy.button(10) == "Add 10 min" && HabitMinutesCopy.button(5) == "Add 5 min")
    }

    @Test func anEntryHandAddedIsListedWithItsTime() {
        let utc = TimeZone(identifier: "UTC")!
        let at = DayBoundary(rolloverMinute: 0, timeZone: utc).instant(of: today, atMinute: 9 * 60 + 12)
        #expect(HabitMinutesCopy.sessionLine(minutes: 10, at: at, timeZone: utc) == "10 min · 09:12")
    }

    @Test func everyRefusalIsSaidCalmly() {
        for error in [HabitMinutesError.notATimedHabit, .minutesOutOfRange, .dayNotOpenForCorrection] {
            #expect(!HabitMinutesCopy.message(for: error).isEmpty)
        }
        #expect(HabitMinutesCopy.message(for: .minutesOutOfRange) == "Add between 1 minute and 12 hours.")
        #expect(HabitMinutesCopy.message(for: .dayNotOpenForCorrection).contains("two weeks"))
    }
}
