//
//  CalendarDatePickerTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The day a date picker returns, read in the person's own calendar.
struct CalendarDatePickerTests {

    private func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    private func instant(_ zone: String, hour: Int, day: Int = 12) -> Date {
        calendar(zone).date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: 30))!
    }

    @Test(arguments: [0, 6, 9, 14, 23])
    func aPickInSydneyKeepsItsDayAtAnyTimeOfDay(hour: Int) {
        let sydney = calendar("Australia/Sydney")
        #expect(CalendarDate(pickerDate: instant("Australia/Sydney", hour: hour), calendar: sydney) == CalendarDate(year: 2026, month: 10, day: 12))
    }

    @Test(arguments: [0, 6, 9, 14, 23])
    func aPickInLosAngelesKeepsItsDayAtAnyTimeOfDay(hour: Int) {
        let la = calendar("America/Los_Angeles")
        #expect(CalendarDate(pickerDate: instant("America/Los_Angeles", hour: hour), calendar: la) == CalendarDate(year: 2026, month: 10, day: 12))
    }

    @Test func theUTCReadingWouldHaveGotTheMorningWrong() {
        // 08:30 on the 12th in Sydney is the 11th in UTC: the reason this exists.
        let morning = instant("Australia/Sydney", hour: 8)
        #expect(CalendarDate(storedDate: morning) == CalendarDate(year: 2026, month: 10, day: 11))
        #expect(CalendarDate(pickerDate: morning, calendar: calendar("Australia/Sydney")) == CalendarDate(year: 2026, month: 10, day: 12))
    }

    @Test func writingADayBackIsNoonInTheCalendarAndRoundTrips() {
        for zone in ["Australia/Sydney", "America/Los_Angeles", "UTC", "Pacific/Kiritimati"] {
            let c = calendar(zone)
            let day = CalendarDate(year: 2026, month: 10, day: 12)!
            let picker = day.pickerDate(calendar: c)
            #expect(c.component(.hour, from: picker) == 12)
            #expect(CalendarDate(pickerDate: picker, calendar: c) == day)
        }
    }
}
