import Foundation

/// The app's day boundary: the day rolls over at a user-set time (default midnight), and
/// "today" always means the **logical date** — the calendar date of *now minus the rollover*.
/// With the default it is the ordinary calendar day; with, say, a 03:00 rollover, 00:30 is
/// still the previous day everywhere.
///
/// Times of day are read from the local wall clock in `timeZone`, so the maths is safe across
/// daylight-saving changes. See docs/architecture/rules-engine.md, "The day boundary".
public struct DayBoundary: Sendable {
    /// Minutes after local midnight when the day rolls over (0 = midnight).
    public let rolloverMinute: Int
    public let timeZone: TimeZone

    /// `rolloverMinute` is clamped to a valid minute of the day; the settings layer is
    /// responsible for the stricter rule that it must be earlier than the working-day start.
    public init(rolloverMinute: Int = 0, timeZone: TimeZone = .current) {
        self.rolloverMinute = min(max(rolloverMinute, 0), 1_439)
        self.timeZone = timeZone
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    // MARK: Logical dates

    /// The logical date at `instant`.
    public func logicalDate(at instant: Date) -> CalendarDate {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        let minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let local = CalendarDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
            ?? CalendarDate(storedDate: instant)
        return minuteOfDay < rolloverMinute ? local.addingDays(-1) : local
    }

    /// The real instant at which local wall-clock minute `minute` occurs on `date`
    /// (for example a working day's 08:00). In a daylight-saving gap it resolves to the next
    /// valid time.
    public func instant(of date: CalendarDate, atMinute minute: Int) -> Date {
        let components = DateComponents(
            year: date.year, month: date.month, day: date.day,
            hour: minute / 60, minute: minute % 60
        )
        return calendar.date(from: components) ?? date.storedDate
    }

    /// The instant the logical day `date` starts.
    public func startInstant(of date: CalendarDate) -> Date {
        instant(of: date, atMinute: rolloverMinute)
    }

    // MARK: Catching up

    /// The logical days that have ended since the engine last ran, **oldest first**.
    ///
    /// `lastProcessed` is the most recent ended day already processed. The result is every day
    /// strictly after it and strictly before today, so rollover work can be caught up lazily
    /// (on launch, on foreground, when synced data arrives) and idempotently.
    public func endedDays(after lastProcessed: CalendarDate, at now: Date) -> [CalendarDate] {
        let today = logicalDate(at: now)
        let gap = lastProcessed.days(until: today)
        guard gap > 1 else { return [] }
        return (1..<gap).map { lastProcessed.addingDays($0) }
    }

    // MARK: Night Planning

    /// What Night Planning plans for, and the day it reviews.
    public struct PlanningTarget: Equatable, Sendable {
        /// The date being planned.
        public let forDate: CalendarDate
        /// The day under review: always `forDate` minus one.
        public let reviewDate: CalendarDate
    }

    /// The plan is for the **first date whose working-day start is still in the future**; the
    /// day it reviews is that date minus one. At 23:00 that is tomorrow; at 00:30 with a
    /// midnight rollover it is today's new date (the morning the user is about to wake into).
    public func planningTarget(at now: Date, dayStartMinute: Int) -> PlanningTarget {
        let logical = logicalDate(at: now)
        let todaysStart = instant(of: logical, atMinute: dayStartMinute)
        let target = now < todaysStart ? logical : logical.addingDays(1)
        return PlanningTarget(forDate: target, reviewDate: target.addingDays(-1))
    }
}
