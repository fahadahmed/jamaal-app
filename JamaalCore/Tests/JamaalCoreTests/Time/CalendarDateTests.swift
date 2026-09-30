import Foundation
import Testing
@testable import JamaalCore

/// A `CalendarDate` is a *floating* calendar date: stored as a `Date` at 12:00 UTC of that
/// date, so every device shows the same day whatever its time zone (see
/// docs/architecture/rules-engine.md, "The day boundary").
struct CalendarDateTests {

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: Construction and validity

    @Test(arguments: [
        (2026, 9, 30), (2026, 1, 1), (2026, 12, 31),
        (2028, 2, 29),  // leap day
    ])
    func acceptsValidDates(year: Int, month: Int, day: Int) {
        let date = CalendarDate(year: year, month: month, day: day)
        #expect(date?.year == year)
        #expect(date?.month == month)
        #expect(date?.day == day)
    }

    @Test(arguments: [
        (2026, 2, 29),   // not a leap year
        (2100, 2, 29),   // century, not a leap year
        (2026, 13, 1),
        (2026, 0, 10),
        (2026, 4, 31),
        (2026, 6, 0),
    ])
    func rejectsInvalidDates(year: Int, month: Int, day: Int) {
        #expect(CalendarDate(year: year, month: month, day: day) == nil)
    }

    // MARK: Stored form (noon UTC)

    @Test func storedDateIsNoonUTC() throws {
        let date = try #require(CalendarDate(year: 2026, month: 9, day: 30))
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date.storedDate)
        #expect(parts.year == 2026)
        #expect(parts.month == 9)
        #expect(parts.day == 30)
        #expect(parts.hour == 12)
        #expect(parts.minute == 0)
        #expect(parts.second == 0)
    }

    /// (zone, how many days the *local* calendar date of the stored instant differs from the
    /// intended date). Reading a stored date in the device's local zone would be wrong in
    /// the zones east of UTC+12 (and sometimes Auckland); decoding is always UTC, so it isn't.
    @Test(arguments: [
        ("UTC", 0),
        ("America/New_York", 0),       // 12:00Z is 07:00 that day
        ("Pacific/Pago_Pago", 0),      // UTC-11: 01:00 that day
        ("Pacific/Auckland", 1),       // 29 Feb 2028 is NZDT (UTC+13): 01:00 the next day
        ("Pacific/Kiritimati", 1),     // UTC+14: 02:00 the next day
    ])
    func storedFormDecodesIdenticallyInEveryTimeZone(zone: String, localDayOffset: Int) throws {
        let original = try #require(CalendarDate(year: 2028, month: 2, day: 29))
        #expect(CalendarDate(storedDate: original.storedDate) == original)

        var local = Calendar(identifier: .gregorian)
        local.timeZone = try #require(TimeZone(identifier: zone))
        let localDay = local.component(.day, from: original.storedDate)
        let expectedDay = localDayOffset == 0 ? 29 : 1   // 29 Feb + 1 day = 1 Mar
        #expect(localDay == expectedDay)
    }

    @Test func decodingToleratesAnyInstantOnThatUTCDate() throws {
        let noon = try #require(CalendarDate(year: 2026, month: 9, day: 30)).storedDate
        #expect(CalendarDate(storedDate: noon.addingTimeInterval(-11 * 3600 - 59 * 60)) == CalendarDate(year: 2026, month: 9, day: 30))  // 00:01 UTC
        #expect(CalendarDate(storedDate: noon.addingTimeInterval(11 * 3600 + 59 * 60)) == CalendarDate(year: 2026, month: 9, day: 30))   // 23:59 UTC
    }

    // MARK: ISO string (used inside JSON config: configData, pausesData)

    @Test(arguments: ["2026-09-30", "2026-01-01", "2028-02-29", "2027-12-31"])
    func isoStringRoundTrips(text: String) throws {
        let date = try #require(CalendarDate(isoString: text))
        #expect(date.isoString == text)
    }

    @Test(arguments: ["2026-9-30", "30-09-2026", "2026-02-30", "2026-13-01", "", "not a date", "2026-09-30T12:00:00Z"])
    func rejectsMalformedISOStrings(text: String) {
        #expect(CalendarDate(isoString: text) == nil)
    }

    @Test func encodesAsISOString() throws {
        let date = try #require(CalendarDate(year: 2026, month: 9, day: 30))
        let data = try JSONEncoder().encode([date])
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-09-30\"]")
        #expect(try JSONDecoder().decode([CalendarDate].self, from: data) == [date])
    }

    // MARK: Weekday (ISO: Monday = 1 … Sunday = 7)

    @Test(arguments: [
        ((2026, 9, 28), 1),  // Monday
        ((2026, 9, 29), 2),
        ((2026, 9, 30), 3),  // Wednesday
        ((2026, 10, 1), 4),
        ((2026, 10, 2), 5),
        ((2026, 10, 3), 6),
        ((2026, 10, 4), 7),  // Sunday
    ])
    func isoWeekday(input: (Int, Int, Int), expected: Int) throws {
        let date = try #require(CalendarDate(year: input.0, month: input.1, day: input.2))
        #expect(date.isoWeekday == expected)
    }

    // MARK: Arithmetic

    @Test(arguments: [
        ((2026, 9, 30), 1, (2026, 10, 1)),
        ((2026, 12, 31), 1, (2027, 1, 1)),
        ((2028, 2, 28), 1, (2028, 2, 29)),
        ((2027, 2, 28), 1, (2027, 3, 1)),
        ((2026, 10, 1), -1, (2026, 9, 30)),
        ((2027, 1, 1), -1, (2026, 12, 31)),
        ((2026, 9, 30), 0, (2026, 9, 30)),
        ((2026, 9, 30), 365, (2027, 9, 30)),
    ])
    func addingDays(start: (Int, Int, Int), days: Int, expected: (Int, Int, Int)) throws {
        let date = try #require(CalendarDate(year: start.0, month: start.1, day: start.2))
        let want = try #require(CalendarDate(year: expected.0, month: expected.1, day: expected.2))
        #expect(date.addingDays(days) == want)
    }

    @Test func daysUntil() throws {
        let a = try #require(CalendarDate(year: 2026, month: 9, day: 30))
        let b = try #require(CalendarDate(year: 2026, month: 10, day: 3))
        #expect(a.days(until: b) == 3)
        #expect(b.days(until: a) == -3)
        #expect(a.days(until: a) == 0)
    }

    @Test func ordersChronologically() throws {
        let a = try #require(CalendarDate(year: 2026, month: 12, day: 31))
        let b = try #require(CalendarDate(year: 2027, month: 1, day: 1))
        let c = try #require(CalendarDate(year: 2026, month: 9, day: 30))
        #expect(a < b)
        #expect(c < a)
        #expect([b, a, c].sorted() == [c, a, b])
    }
}
