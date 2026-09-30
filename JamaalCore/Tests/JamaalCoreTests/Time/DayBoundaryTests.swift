import Foundation
import Testing
@testable import JamaalCore

/// The day boundary from docs/architecture/rules-engine.md: the app's day rolls over at a
/// user-set time (default midnight). "Today" is always the *logical date*.
struct DayBoundaryTests {

    // MARK: Helpers

    private static let utc = TimeZone(identifier: "UTC")!
    private static let auckland = TimeZone(identifier: "Pacific/Auckland")!
    private static let newYork = TimeZone(identifier: "America/New_York")!

    private static func instant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, in zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: year, month: month, day: day)!
    }

    private static func iso(_ instant: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = utc
        return formatter.string(from: instant)
    }

    struct LogicalDateCase: Sendable, CustomTestStringConvertible {
        let zone: String
        let rolloverMinute: Int
        let local: (year: Int, month: Int, day: Int, hour: Int, minute: Int)
        let expected: (year: Int, month: Int, day: Int)
        var testDescription: String {
            "\(zone) rollover \(rolloverMinute) @ \(local.year)-\(local.month)-\(local.day) \(local.hour):\(local.minute) → \(expected.year)-\(expected.month)-\(expected.day)"
        }
    }

    // MARK: Logical date

    @Test(arguments: [
        // Default midnight rollover: the ordinary calendar day.
        LogicalDateCase(zone: "UTC", rolloverMinute: 0, local: (2026, 9, 30, 0, 0), expected: (2026, 9, 30)),
        LogicalDateCase(zone: "UTC", rolloverMinute: 0, local: (2026, 9, 30, 23, 59), expected: (2026, 9, 30)),
        LogicalDateCase(zone: "UTC", rolloverMinute: 0, local: (2026, 10, 1, 0, 0), expected: (2026, 10, 1)),
        // A 03:00 rollover keeps a late evening on the same logical day.
        LogicalDateCase(zone: "UTC", rolloverMinute: 180, local: (2026, 10, 1, 0, 30), expected: (2026, 9, 30)),
        LogicalDateCase(zone: "UTC", rolloverMinute: 180, local: (2026, 10, 1, 2, 59), expected: (2026, 9, 30)),
        LogicalDateCase(zone: "UTC", rolloverMinute: 180, local: (2026, 10, 1, 3, 0), expected: (2026, 10, 1)),
        // The month and year boundaries move with it.
        LogicalDateCase(zone: "UTC", rolloverMinute: 180, local: (2027, 1, 1, 1, 0), expected: (2026, 12, 31)),
        LogicalDateCase(zone: "UTC", rolloverMinute: 180, local: (2026, 3, 1, 2, 0), expected: (2026, 2, 28)),
        // Local time zones: the date is the *local* one, not UTC's.
        LogicalDateCase(zone: "Pacific/Auckland", rolloverMinute: 0, local: (2026, 9, 30, 0, 5), expected: (2026, 9, 30)),
        LogicalDateCase(zone: "America/New_York", rolloverMinute: 0, local: (2026, 9, 30, 23, 55), expected: (2026, 9, 30)),
        LogicalDateCase(zone: "Pacific/Auckland", rolloverMinute: 240, local: (2026, 9, 30, 3, 59), expected: (2026, 9, 29)),
    ])
    func logicalDate(_ c: LogicalDateCase) {
        let zone = TimeZone(identifier: c.zone)!
        let boundary = DayBoundary(rolloverMinute: c.rolloverMinute, timeZone: zone)
        let now = Self.instant(c.local.year, c.local.month, c.local.day, c.local.hour, c.local.minute, in: zone)
        #expect(boundary.logicalDate(at: now) == Self.date(c.expected.year, c.expected.month, c.expected.day))
    }

    @Test func logicalDateAcrossASpringForwardTransition() {
        // Auckland, 27 Sep 2026: at 02:00 NZST clocks jump to 03:00 NZDT, so the wall clock
        // never shows 02:xx. With a 03:00 rollover the new day starts the moment it reads 03:00.
        let boundary = DayBoundary(rolloverMinute: 180, timeZone: Self.auckland)
        let justBefore = Self.instant(2026, 9, 27, 1, 59, in: Self.auckland)
        let justAfter = Self.instant(2026, 9, 27, 3, 0, in: Self.auckland)
        #expect(boundary.logicalDate(at: justBefore) == Self.date(2026, 9, 26))
        #expect(boundary.logicalDate(at: justAfter) == Self.date(2026, 9, 27))
    }

    @Test func logicalDateDuringARepeatedHourOnFallBack() {
        // New York, 1 Nov 2026: 01:00–01:59 happens twice. Both occurrences are the same
        // wall-clock time, so with a 01:30 rollover both are already the new day.
        let boundary = DayBoundary(rolloverMinute: 90, timeZone: Self.newYork)
        let firstPass = Date(timeIntervalSince1970: Self.instant(2026, 11, 1, 0, 0, in: Self.newYork).timeIntervalSince1970 + 105 * 60)       // 01:45 EDT
        let secondPass = Date(timeIntervalSince1970: Self.instant(2026, 11, 1, 0, 0, in: Self.newYork).timeIntervalSince1970 + 165 * 60)      // 01:45 EST
        #expect(boundary.logicalDate(at: firstPass) == Self.date(2026, 11, 1))
        #expect(boundary.logicalDate(at: secondPass) == Self.date(2026, 11, 1))
    }

    // MARK: When a logical day starts

    @Test func startInstantWithDefaultRolloverIsLocalMidnight() {
        let boundary = DayBoundary(rolloverMinute: 0, timeZone: Self.auckland)
        let start = boundary.startInstant(of: Self.date(2026, 9, 27))
        // Auckland is UTC+12 on the night of 26–27 Sep (before clocks change at 02:00).
        #expect(Self.iso(start) == "2026-09-26T12:00:00Z")
    }

    @Test func startInstantIncludesTheRolloverOffset() {
        let boundary = DayBoundary(rolloverMinute: 180, timeZone: Self.utc)
        #expect(Self.iso(boundary.startInstant(of: Self.date(2026, 10, 1))) == "2026-10-01T03:00:00Z")
    }

    @Test func aDayStartsExactlyWhereItsLogicalDateBegins() {
        let boundary = DayBoundary(rolloverMinute: 150, timeZone: Self.newYork)
        let day = Self.date(2026, 10, 15)
        let start = boundary.startInstant(of: day)
        #expect(boundary.logicalDate(at: start) == day)
        #expect(boundary.logicalDate(at: start.addingTimeInterval(-1)) == day.addingDays(-1))
    }

    // MARK: Catching up on ended days

    @Test func endedDaysAreOldestFirstAndExcludeTodayAndWhatWasProcessed() {
        let boundary = DayBoundary(rolloverMinute: 0, timeZone: Self.utc)
        let now = Self.instant(2026, 10, 1, 9, 0, in: Self.utc)   // logical today: 1 Oct
        let ended = boundary.endedDays(after: Self.date(2026, 9, 28), at: now)
        #expect(ended == [Self.date(2026, 9, 29), Self.date(2026, 9, 30)])
    }

    @Test func noEndedDaysWhenAlreadyCaughtUp() {
        let boundary = DayBoundary(rolloverMinute: 0, timeZone: Self.utc)
        let now = Self.instant(2026, 10, 1, 9, 0, in: Self.utc)
        #expect(boundary.endedDays(after: Self.date(2026, 9, 30), at: now).isEmpty)   // yesterday already done
        #expect(boundary.endedDays(after: Self.date(2026, 10, 1), at: now).isEmpty)   // never ahead of today
        #expect(boundary.endedDays(after: Self.date(2026, 10, 9), at: now).isEmpty)   // clock went backwards
    }

    @Test func endedDaysRespectACustomRollover() {
        // 01:00 on 1 Oct with a 03:00 rollover is still logical 30 Sep, so 30 Sep has not ended.
        let boundary = DayBoundary(rolloverMinute: 180, timeZone: Self.utc)
        let now = Self.instant(2026, 10, 1, 1, 0, in: Self.utc)
        #expect(boundary.endedDays(after: Self.date(2026, 9, 28), at: now) == [Self.date(2026, 9, 29)])
    }

    // MARK: Night Planning's target day

    struct PlanningCase: Sendable, CustomTestStringConvertible {
        let rolloverMinute: Int
        let local: (year: Int, month: Int, day: Int, hour: Int, minute: Int)
        let target: (year: Int, month: Int, day: Int)
        let review: (year: Int, month: Int, day: Int)
        var testDescription: String {
            "rollover \(rolloverMinute) @ \(local.year)-\(local.month)-\(local.day) \(local.hour):\(local.minute) → plans \(target.year)-\(target.month)-\(target.day)"
        }
    }

    /// The plan is for the first date whose working-day start (here 08:00) is still in the
    /// future; the day reviewed is that date minus one.
    @Test(arguments: [
        PlanningCase(rolloverMinute: 0,   local: (2026, 9, 30, 23, 0),  target: (2026, 10, 1), review: (2026, 9, 30)),   // the usual evening
        PlanningCase(rolloverMinute: 0,   local: (2026, 10, 1, 0, 30),  target: (2026, 10, 1), review: (2026, 9, 30)),   // 00:30: the morning about to start
        PlanningCase(rolloverMinute: 180, local: (2026, 10, 1, 0, 30),  target: (2026, 10, 1), review: (2026, 9, 30)),   // custom rollover: still the old day
        PlanningCase(rolloverMinute: 0,   local: (2026, 10, 1, 6, 30),  target: (2026, 10, 1), review: (2026, 9, 30)),   // before the working day starts
        PlanningCase(rolloverMinute: 0,   local: (2026, 10, 1, 8, 0),   target: (2026, 10, 2), review: (2026, 10, 1)),   // exactly at start: no longer in the future
        PlanningCase(rolloverMinute: 0,   local: (2026, 10, 1, 12, 0),  target: (2026, 10, 2), review: (2026, 10, 1)),
        PlanningCase(rolloverMinute: 180, local: (2026, 10, 1, 3, 30),  target: (2026, 10, 1), review: (2026, 9, 30)),   // just after a 03:00 rollover
        PlanningCase(rolloverMinute: 0,   local: (2026, 12, 31, 22, 0), target: (2027, 1, 1),  review: (2026, 12, 31)),  // year boundary
    ])
    func planningTarget(_ c: PlanningCase) {
        let boundary = DayBoundary(rolloverMinute: c.rolloverMinute, timeZone: Self.utc)
        let now = Self.instant(c.local.year, c.local.month, c.local.day, c.local.hour, c.local.minute, in: Self.utc)
        let result = boundary.planningTarget(at: now, dayStartMinute: 480)
        #expect(result.forDate == Self.date(c.target.year, c.target.month, c.target.day))
        #expect(result.reviewDate == Self.date(c.review.year, c.review.month, c.review.day))
    }

    @Test func workingDayStartIsWallClockOnThatDate() {
        // The instant for "08:00 on 27 Sep" in Auckland is after the clocks change, so it is NZDT (UTC+13).
        let boundary = DayBoundary(rolloverMinute: 0, timeZone: Self.auckland)
        let eight = boundary.instant(of: Self.date(2026, 9, 27), atMinute: 480)
        #expect(Self.iso(eight) == "2026-09-26T19:00:00Z")
    }
}
