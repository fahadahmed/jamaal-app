import Foundation
import SwiftData

public enum PrayerEditError: Error, Equatable, Sendable {
    case emptyTitle
    case noPrayers
    case unknownPrayer
    case unknownMethod
    /// A madhab, "Isha ends" or high-latitude choice the engine doesn't know.
    case unknownOption
    /// Prayer times need a place: no location, or one that isn't on the map.
    case noLocation
    case adjustmentOutOfRange
}

/// The calculation methods the form offers: exactly the set the prayer-time library provides (its custom-angle one isn't offered).
public enum PrayerMethods {
    public static let all: [(key: String, title: String)] = [
        ("muslimWorldLeague", "Muslim World League"),
        ("egyptian", "Egyptian General Authority"),
        ("karachi", "University of Islamic Sciences, Karachi"),
        ("ummAlQura", "Umm al-Qura"),
        ("dubai", "Dubai"),
        ("moonsightingCommittee", "Moonsighting Committee"),
        ("northAmerica", "North America (ISNA)"),
        ("kuwait", "Kuwait"),
        ("qatar", "Qatar"),
        ("singapore", "Singapore"),
        ("tehran", "Tehran"),
        ("turkey", "Turkey (Diyanet)"),
    ]

    /// The method's name; anything unknown reads as the Muslim World League, as it is calculated.
    public static func title(for key: String) -> String {
        all.first { $0.key == key }?.title ?? "Muslim World League"
    }
}

/// Where prayer times are worked out: coarse coordinates, and when a device may move the stored place.
public enum PrayerLocationRules {
    /// A device must have moved about this far, by its own measure, before it rewrites the rule's place.
    public static let movementThresholdKilometres = 25.0

    /// A place kept to about a kilometre (two decimal places): precise coordinates are never stored or synced.
    public static func coarse(mode: String, latitude: Double, longitude: Double, name: String?) -> PrayerConfig.Location {
        func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }
        return PrayerConfig.Location(mode: mode, latitude: round2(latitude), longitude: round2(longitude), name: name)
    }

    /// Great-circle distance in kilometres.
    public static func kilometres(from a: PrayerConfig.Location, to b: PrayerConfig.Location) -> Double {
        let radius = 6371.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1, dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }

    /// The place to store after a device reading, or `nil` to leave it. A chosen city (`manual`) never follows the
    /// device; a `device` place moves only when this device has itself moved about 25 km, so a Mac at home never
    /// writes and a travelling iPhone does.
    public static func updatedPlace(stored: PrayerConfig.Location?, device: PrayerConfig.Location) -> PrayerConfig.Location? {
        guard let stored else { return device }
        guard stored.mode == "device" else { return nil }
        return kilometres(from: stored, to: device) >= movementThresholdKilometres ? device : nil
    }
}

/// What the prayer form collects (AN-04). The windows come from astronomy, so there are no times to type.
public struct PrayerRuleDraft: Equatable {
    public var title = "Salah"
    public var location: PrayerConfig.Location?
    public var method: String
    public var madhab: String
    public var highLatitude = "middleOfNight"
    public var ishaEnds = "midnight"
    public var fridayLabel = true
    public var prayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
    public var adjustments: [String: Int] = [:]
    public var effortMinutes: Int? = 10
    public var remindAtStart = true
    public var remindBeforeEndMinutes: Int?

    /// Method and madhab pre-selected for a country (the owner reviews that table); the user can change both.
    public init(countryCode: String?) {
        let suggestion = PrayerMethodSuggestion.forCountry(countryCode)
        method = suggestion.method
        madhab = suggestion.madhab
    }

    public mutating func applySuggestion(forCountry code: String?) {
        let suggestion = PrayerMethodSuggestion.forCountry(code)
        method = suggestion.method
        madhab = suggestion.madhab
    }

    /// The form for an existing prayer rule; `nil` for any other.
    public init?(editing rule: AnchorRule) {
        guard case .prayer(let config) = rule.config else { return nil }
        self.init(countryCode: nil)
        title = rule.title
        location = config.location
        method = config.method
        madhab = config.madhab
        highLatitude = config.highLatitude
        ishaEnds = config.ishaEnds
        fridayLabel = config.fridayLabel
        prayers = config.prayers
        adjustments = config.adjustmentsMinutes
        effortMinutes = rule.effortMinutes
        remindAtStart = config.reminder?.atStart ?? false
        remindBeforeEndMinutes = config.reminder?.beforeEndMinutes
    }
}

public enum PrayerEditing {
    private static let order = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

    /// Validates the draft and inserts the rule: fixed at the start of each window, reminding at the start unless told
    /// otherwise. Nothing is written when it is refused.
    @MainActor
    @discardableResult
    public static func create(_ draft: PrayerRuleDraft, in context: ModelContext, now: Date) throws -> AnchorRule {
        let config = try validatedConfig(draft, exceptions: [])
        let rule = AnchorRule(title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines))
        rule.createdAt = now
        rule.source = .prayerWindow
        rule.placementKind = .fixed
        rule.effortMinutes = draft.effortMinutes.flatMap { $0 > 0 ? $0 : nil }
        rule.configData = config.json
        context.insert(rule)
        return rule
    }

    /// Applies the form to an existing prayer rule, keeping its exceptions. Nothing is written when it is refused.
    @MainActor
    public static func update(_ rule: AnchorRule, with draft: PrayerRuleDraft) throws {
        guard case .prayer(let existing) = rule.config else { throw AnchorEditError.notAScheduledRule }
        let config = try validatedConfig(draft, exceptions: existing.exceptions)
        rule.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        rule.effortMinutes = draft.effortMinutes.flatMap { $0 > 0 ? $0 : nil }
        rule.configData = config.json
    }

    /// Moves a `device` rule's stored place to a reading from this device, only when this device has moved about 25 km
    /// (or the rule has none). A chosen city never moves. Returns whether it changed.
    @MainActor
    @discardableResult
    public static func followDevice(_ rule: AnchorRule, reading: PrayerConfig.Location) -> Bool {
        guard case .prayer(var config) = rule.config,
              let place = PrayerLocationRules.updatedPlace(stored: config.location, device: reading) else { return false }
        config.location = place
        rule.configData = config.json
        return true
    }

    /// Today's prayers still to come with these settings: what the form says "will appear". Empty with no place.
    public static func upcomingToday(_ draft: PrayerRuleDraft, now: Date, boundary: DayBoundary) -> [PrayerWindow] {
        guard let config = try? validatedConfig(draft, exceptions: []) else { return [] }
        return PrayerWindows.windows(config: config, on: boundary.logicalDate(at: now)).filter { $0.end > now }
    }

    private static func validatedConfig(_ draft: PrayerRuleDraft, exceptions: [AnchorException]) throws -> PrayerConfig {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PrayerEditError.emptyTitle }
        guard !draft.prayers.isEmpty else { throw PrayerEditError.noPrayers }
        guard draft.prayers.allSatisfy(order.contains) else { throw PrayerEditError.unknownPrayer }
        guard PrayerMethods.all.contains(where: { $0.key == draft.method }) else { throw PrayerEditError.unknownMethod }
        guard ["shafi", "hanafi"].contains(draft.madhab), ["midnight", "fajr"].contains(draft.ishaEnds),
              ["middleOfNight", "seventhOfNight", "twilightAngle"].contains(draft.highLatitude) else { throw PrayerEditError.unknownOption }
        guard let location = draft.location, (-90...90).contains(location.latitude), (-180...180).contains(location.longitude) else {
            throw PrayerEditError.noLocation
        }
        guard draft.adjustments.values.allSatisfy({ (-60...60).contains($0) }) else { throw PrayerEditError.adjustmentOutOfRange }

        let reminder = (draft.remindAtStart || draft.remindBeforeEndMinutes != nil)
            ? AnchorReminder(atStart: draft.remindAtStart, beforeEndMinutes: draft.remindBeforeEndMinutes) : nil
        return PrayerConfig(
            method: draft.method, madhab: draft.madhab, highLatitude: draft.highLatitude, ishaEnds: draft.ishaEnds,
            fridayLabel: draft.fridayLabel, reminder: reminder, prayers: order.filter(Set(draft.prayers).contains),
            adjustmentsMinutes: draft.adjustments.filter { $0.value != 0 }, location: location, exceptions: exceptions)
    }
}
