import Foundation

/// A *floating* calendar date: a year, month and day with no time and no time zone.
///
/// Day-level data (a task's due date, a habit entry's day, an Anchor's occurrence date)
/// must mean the same day on every device, wherever it is. So the stored form is a `Date`
/// at **12:00 UTC** of that calendar date, and decoding is always done in UTC. Times of day
/// (Anchor windows, session start and end) are real instants and are not `CalendarDate`s.
///
/// All arithmetic is plain integer day counting (proleptic Gregorian), so nothing here
/// depends on the device's time zone, locale or `Calendar`.
public struct CalendarDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Returns `nil` for a date that does not exist (30 February, month 13, …).
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1, day <= Self.daysInMonth(year: year, month: month) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    // MARK: Stored form (noon UTC)

    /// The `Date` to persist: 12:00 UTC on this calendar date.
    public var storedDate: Date {
        Date(timeIntervalSince1970: Double(daysSinceEpoch) * 86_400 + 43_200)
    }

    /// Reads a persisted date. Any instant on that *UTC* date decodes to it, so a little
    /// drift in a stored value never moves it to another day.
    public init(storedDate: Date) {
        let days = Int((storedDate.timeIntervalSince1970 / 86_400).rounded(.down))
        self = Self.fromDaysSinceEpoch(days)
    }

    // MARK: ISO string (yyyy-MM-dd), used inside JSON config

    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Strict: exactly `yyyy-MM-dd`, and a real date.
    public init?(isoString: String) {
        let characters = Array(isoString.utf8)
        guard characters.count == 10, characters[4] == UInt8(ascii: "-"), characters[7] == UInt8(ascii: "-") else {
            return nil
        }
        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for index in range {
                let byte = characters[index]
                guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else { return nil }
                value = value * 10 + Int(byte - UInt8(ascii: "0"))
            }
            return value
        }
        guard let year = number(0..<4), let month = number(5..<7), let day = number(8..<10) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    // MARK: Weekday and arithmetic

    /// ISO weekday: Monday = 1 … Sunday = 7.
    public var isoWeekday: Int {
        // 1970-01-01 was a Thursday (ISO 4).
        let value = (daysSinceEpoch + 3) % 7
        return (value < 0 ? value + 7 : value) + 1
    }

    public func addingDays(_ days: Int) -> CalendarDate {
        Self.fromDaysSinceEpoch(daysSinceEpoch + days)
    }

    /// Whole days from `self` to `other` (negative if `other` is earlier).
    public func days(until other: CalendarDate) -> Int {
        other.daysSinceEpoch - daysSinceEpoch
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: Civil-calendar arithmetic (days since 1970-01-01)

    private var daysSinceEpoch: Int {
        // Howard Hinnant's days_from_civil.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = month + (month > 2 ? -3 : 9)
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func fromDaysSinceEpoch(_ days: Int) -> CalendarDate {
        // Howard Hinnant's civil_from_days.
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth + (shiftedMonth < 10 ? 3 : -9)
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        // The arithmetic only ever produces real dates.
        return CalendarDate(year: year, month: month, day: day)!
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        default:
            let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return isLeap ? 29 : 28
        }
    }
}

/// Encoded as its ISO string (`"2026-09-30"`), which is also how dates appear inside the
/// JSON config fields (`AnchorRule.configData`, `Habit.pausesData`).
extension CalendarDate: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = CalendarDate(isoString: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a yyyy-MM-dd date: \(text)")
        }
        self = date
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}
