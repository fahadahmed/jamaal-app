import Foundation

/// A date range when a rule's windows don't exist at all (term break, holiday, travel, illness).
/// `to == nil` is open-ended. For display only: the reason is kept as its raw string.
public struct AnchorException: Codable, Equatable, Sendable {
    public var from: CalendarDate
    public var to: CalendarDate?
    public var reason: String

    public init(from: CalendarDate, to: CalendarDate?, reason: String) {
        self.from = from
        self.to = to
        self.reason = reason
    }

    public var reasonKind: ExceptionReason { ExceptionReason(stored: reason) }

    public func covers(_ day: CalendarDate) -> Bool { from <= day && (to.map { day <= $0 } ?? true) }

    private enum CodingKeys: String, CodingKey { case from, to, reason }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = try c.decode(CalendarDate.self, forKey: .from)
        to = try c.decodeIfPresent(CalendarDate.self, forKey: .to)
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ExceptionReason.other.rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(from, forKey: .from)
        if let to { try c.encode(to, forKey: .to) } else { try c.encodeNil(forKey: .to) }
        try c.encode(reason, forKey: .reason)
    }
}

public struct AnchorReminder: Codable, Equatable, Sendable {
    /// A reminder when the window opens.
    public var atStart: Bool
    /// A closing reminder this many minutes before the window ends; opt-in.
    public var beforeEndMinutes: Int?

    public init(atStart: Bool, beforeEndMinutes: Int?) {
        self.atStart = atStart
        self.beforeEndMinutes = beforeEndMinutes
    }
}

/// A named time slot of a scheduled rule; each occurrence day generates one Anchor per slot.
public struct AnchorSlot: Codable, Equatable, Sendable {
    /// Stable, never reused: it is the generated Anchor's `slotKey`.
    public var id: String
    public var label: String
    /// Local wall-clock `"HH:mm"`, so travelling keeps 08:15 as 08:15.
    public var start: String
    public var windowMinutes: Int
    /// The window is the whole day; `start` and `windowMinutes` are ignored.
    public var allDay: Bool

    public init(id: String, label: String, start: String, windowMinutes: Int, allDay: Bool = false) {
        self.id = id
        self.label = label
        self.start = start
        self.windowMinutes = windowMinutes
        self.allDay = allDay
    }

    private enum CodingKeys: String, CodingKey { case id, label, start, windowMinutes, allDay }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        start = try c.decodeIfPresent(String.self, forKey: .start) ?? "00:00"
        windowMinutes = try c.decodeIfPresent(Int.self, forKey: .windowMinutes) ?? 0
        allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
    }

    /// Minutes after midnight for `start`, or `nil` if it isn't a valid `"HH:mm"`.
    public var startMinute: Int? {
        let parts = start.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }
}

/// When a scheduled rule's days fall.
public enum AnchorRecurrence: Equatable, Sendable {
    case weekly(weekdays: [Int])
    case everyNDays(n: Int, startDate: CalendarDate)
    /// Those weekdays every *n*th week, counting ISO (Monday-first) weeks from the week of `startDate`.
    case everyNWeeks(n: Int, weekdays: [Int], startDate: CalendarDate)
    /// An interval from the last time it was handled, not the calendar. `startDate` is when it was last handled.
    case afterLast(minDays: Int, maxDays: Int, startDate: CalendarDate)

    public var isAfterLast: Bool {
        if case .afterLast = self { return true }
        return false
    }

    /// Whether a calendar-based recurrence has an occurrence on `day`. `afterLast` is stateful, so never.
    public func occurs(on day: CalendarDate) -> Bool {
        switch self {
        case .weekly(let weekdays):
            return weekdays.contains(day.isoWeekday)
        case .everyNDays(let n, let start):
            let days = start.days(until: day)
            return n >= 1 && days >= 0 && days % n == 0
        case .everyNWeeks(let n, let weekdays, let start):
            guard n >= 1, weekdays.contains(day.isoWeekday) else { return false }
            let weeks = Self.monday(of: start).days(until: Self.monday(of: day)) / 7
            return weeks >= 0 && weeks % n == 0
        case .afterLast:
            return false
        }
    }

    private static func monday(of day: CalendarDate) -> CalendarDate { day.addingDays(-(day.isoWeekday - 1)) }

    var isValid: Bool {
        func validDays(_ days: [Int]) -> Bool { !days.isEmpty && days.allSatisfy { (1...7).contains($0) } }
        switch self {
        case .weekly(let weekdays): return validDays(weekdays)
        case .everyNDays(let n, _): return n >= 1
        case .everyNWeeks(let n, let weekdays, _): return n >= 1 && validDays(weekdays)
        case .afterLast(let minDays, let maxDays, _): return minDays >= 1 && maxDays >= minDays
        }
    }
}

extension AnchorRecurrence: Codable {
    private enum CodingKeys: String, CodingKey { case kind, weekdays, n, startDate, minDays, maxDays }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "weekly":
            self = .weekly(weekdays: try c.decode([Int].self, forKey: .weekdays))
        case "everyNDays":
            self = .everyNDays(n: try c.decode(Int.self, forKey: .n), startDate: try c.decode(CalendarDate.self, forKey: .startDate))
        case "everyNWeeks":
            self = .everyNWeeks(n: try c.decode(Int.self, forKey: .n), weekdays: try c.decode([Int].self, forKey: .weekdays),
                                startDate: try c.decode(CalendarDate.self, forKey: .startDate))
        case "afterLast":
            self = .afterLast(minDays: try c.decode(Int.self, forKey: .minDays), maxDays: try c.decode(Int.self, forKey: .maxDays),
                              startDate: try c.decode(CalendarDate.self, forKey: .startDate))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "unknown recurrence kind")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .weekly(let weekdays):
            try c.encode("weekly", forKey: .kind); try c.encode(weekdays, forKey: .weekdays)
        case .everyNDays(let n, let start):
            try c.encode("everyNDays", forKey: .kind); try c.encode(n, forKey: .n); try c.encode(start, forKey: .startDate)
        case .everyNWeeks(let n, let weekdays, let start):
            try c.encode("everyNWeeks", forKey: .kind); try c.encode(n, forKey: .n)
            try c.encode(weekdays, forKey: .weekdays); try c.encode(start, forKey: .startDate)
        case .afterLast(let minDays, let maxDays, let start):
            try c.encode("afterLast", forKey: .kind); try c.encode(minDays, forKey: .minDays)
            try c.encode(maxDays, forKey: .maxDays); try c.encode(start, forKey: .startDate)
        }
    }
}

/// The scheduled family: school run, bin night, plant watering and custom rules.
public struct ScheduledConfig: Codable, Equatable, Sendable {
    public static let supportedVersion = 1

    public var version: Int
    public var recurrence: AnchorRecurrence
    public var slots: [AnchorSlot]
    public var endDate: CalendarDate?
    public var reminder: AnchorReminder?
    public var exceptions: [AnchorException]

    public init(
        version: Int = ScheduledConfig.supportedVersion, recurrence: AnchorRecurrence, slots: [AnchorSlot],
        endDate: CalendarDate? = nil, reminder: AnchorReminder? = nil, exceptions: [AnchorException] = []
    ) {
        self.version = version
        self.recurrence = recurrence
        self.slots = slots
        self.endDate = endDate
        self.reminder = reminder
        self.exceptions = exceptions
    }

    private enum CodingKeys: String, CodingKey { case version, recurrence, slots, endDate, reminder, exceptions }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        recurrence = try c.decode(AnchorRecurrence.self, forKey: .recurrence)
        slots = try c.decodeIfPresent([AnchorSlot].self, forKey: .slots) ?? []
        endDate = try c.decodeIfPresent(CalendarDate.self, forKey: .endDate)
        reminder = try c.decodeIfPresent(AnchorReminder.self, forKey: .reminder)
        exceptions = try c.decodeIfPresent([AnchorException].self, forKey: .exceptions) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(recurrence, forKey: .recurrence)
        try c.encode(slots, forKey: .slots)
        if let endDate { try c.encode(endDate, forKey: .endDate) } else { try c.encodeNil(forKey: .endDate) }
        try c.encodeIfPresent(reminder, forKey: .reminder)
        try c.encode(exceptions, forKey: .exceptions)
    }

    /// The JSON to store in `AnchorRule.configData`.
    public var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// Whether `day` falls inside an exception.
    public func isExcepted(_ day: CalendarDate) -> Bool { exceptions.contains { $0.covers(day) } }

    /// Whether the rule is live on `day`: not past its end date and not inside an exception.
    public func isActive(on day: CalendarDate) -> Bool {
        (endDate.map { day <= $0 } ?? true) && !isExcepted(day)
    }

    var isValid: Bool {
        recurrence.isValid && slots.allSatisfy { slot in
            slot.allDay || (slot.startMinute != nil && slot.windowMinutes >= 1)
        }
    }
}

/// The prayer-time family. Windows come from astronomy (`PrayerWindows`); this is its stored shape.
public struct PrayerConfig: Codable, Equatable, Sendable {
    public struct Location: Codable, Equatable, Sendable {
        public var mode: String
        public var latitude: Double
        public var longitude: Double
        public var name: String?

        public init(mode: String, latitude: Double, longitude: Double, name: String?) {
            self.mode = mode
            self.latitude = latitude
            self.longitude = longitude
            self.name = name
        }
    }

    public var version: Int
    public var method: String
    public var madhab: String
    public var highLatitude: String
    public var ishaEnds: String
    /// Titles Friday's Dhuhr Anchor "Jumu'ah" (same window, time and slot key).
    public var fridayLabel: Bool
    /// Prayer times remind at the start unless the rule says otherwise.
    public var reminder: AnchorReminder?
    public var prayers: [String]
    public var adjustmentsMinutes: [String: Int]
    public var location: Location?
    public var exceptions: [AnchorException]

    public init(
        version: Int = ScheduledConfig.supportedVersion, method: String = "muslimWorldLeague", madhab: String = "shafi",
        highLatitude: String = "middleOfNight", ishaEnds: String = "midnight", fridayLabel: Bool = true,
        reminder: AnchorReminder? = nil, prayers: [String] = ["fajr", "dhuhr", "asr", "maghrib", "isha"],
        adjustmentsMinutes: [String: Int] = [:], location: Location? = nil, exceptions: [AnchorException] = []
    ) {
        self.version = version
        self.method = method
        self.madhab = madhab
        self.highLatitude = highLatitude
        self.ishaEnds = ishaEnds
        self.fridayLabel = fridayLabel
        self.reminder = reminder
        self.prayers = prayers
        self.adjustmentsMinutes = adjustmentsMinutes
        self.location = location
        self.exceptions = exceptions
    }

    private enum CodingKeys: String, CodingKey {
        case version, method, madhab, highLatitude, ishaEnds, fridayLabel, reminder, prayers, adjustmentsMinutes, location, exceptions
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        method = try c.decodeIfPresent(String.self, forKey: .method) ?? "muslimWorldLeague"
        madhab = try c.decodeIfPresent(String.self, forKey: .madhab) ?? "shafi"
        highLatitude = try c.decodeIfPresent(String.self, forKey: .highLatitude) ?? "middleOfNight"
        ishaEnds = try c.decodeIfPresent(String.self, forKey: .ishaEnds) ?? "midnight"
        fridayLabel = try c.decodeIfPresent(Bool.self, forKey: .fridayLabel) ?? true
        reminder = try c.decodeIfPresent(AnchorReminder.self, forKey: .reminder)
        prayers = try c.decodeIfPresent([String].self, forKey: .prayers) ?? ["fajr", "dhuhr", "asr", "maghrib", "isha"]
        adjustmentsMinutes = try c.decodeIfPresent([String: Int].self, forKey: .adjustmentsMinutes) ?? [:]
        location = try c.decodeIfPresent(Location.self, forKey: .location)
        exceptions = try c.decodeIfPresent([AnchorException].self, forKey: .exceptions) ?? []
    }

    /// The JSON to store in `AnchorRule.configData`.
    public var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// Whether `day` falls inside an exception.
    public func isExcepted(_ day: CalendarDate) -> Bool { exceptions.contains { $0.covers(day) } }
}

/// Why a rule can't be generated.
public enum NeedsAttentionReason: Equatable, Sendable {
    /// Written by a newer app than this one understands.
    case newerVersion
    /// Invalid or incomplete.
    case unreadable
}

/// A rule's decoded `configData`: exactly two families, or "needs attention".
public enum AnchorRuleConfig: Equatable, Sendable {
    case scheduled(ScheduledConfig)
    case prayer(PrayerConfig)
    /// Never generated and never deleted; the rules list says "Update Jamaal" or "couldn't be read".
    case needsAttention(NeedsAttentionReason)

    /// Decodes `configData` for a rule with `sourceKey`. A missing or newer `version`, invalid JSON
    /// or an invalid shape never throws: the rule needs attention and its text is left untouched.
    public static func decode(sourceKey: String, configData: String) -> AnchorRuleConfig {
        guard let data = configData.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["version"] as? Int else { return .needsAttention(.unreadable) }
        guard version <= ScheduledConfig.supportedVersion else { return .needsAttention(.newerVersion) }

        let decoder = JSONDecoder()
        if AnchorSource(stored: sourceKey) == .prayerWindow {
            guard let config = try? decoder.decode(PrayerConfig.self, from: data) else { return .needsAttention(.unreadable) }
            return .prayer(config)
        }
        guard let config = try? decoder.decode(ScheduledConfig.self, from: data), config.isValid else {
            return .needsAttention(.unreadable)
        }
        return .scheduled(config)
    }
}

extension AnchorRule {
    /// Whether this is an `afterLast` rule (interval from last done): always flexible, one live instance per slot.
    public var isAfterLast: Bool {
        if case .scheduled(let config) = config { return config.recurrence.isAfterLast }
        return false
    }

    /// Typed view of `configData`. Reading never rewrites it.
    public var config: AnchorRuleConfig {
        AnchorRuleConfig.decode(sourceKey: sourceKey, configData: configData)
    }
}
