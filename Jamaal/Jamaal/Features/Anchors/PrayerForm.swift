//
//  PrayerForm.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// A place found by the device or a city search: coarse enough to store, with the country that pre-selects the method.
struct FoundPlace: Equatable {
    var name: String
    var region: String
    var countryCode: String?
    var latitude: Double
    var longitude: Double

    /// "England, United Kingdom" under a city's name in the search results.
    var detail: String { region }

    func location(mode: String) -> PrayerConfig.Location {
        PrayerLocationRules.coarse(mode: mode, latitude: latitude, longitude: longitude, name: name)
    }
}

/// The prayer times form's state (AN-04): the draft, the country that suggested its method, and the words around it.
struct PrayerForm: Equatable {
    var draft: PrayerRuleDraft
    /// The country the method was suggested for; `nil` once the user has chosen a method themselves, or without one.
    private(set) var suggestedFor: String?
    private var methodWasChosen: Bool

    /// A form over a draft. One that already has a place is an existing rule: its method is the user's own.
    init(draft: PrayerRuleDraft, deviceCountry: String?) {
        self.draft = draft
        methodWasChosen = draft.location != nil
        suggestedFor = draft.location == nil ? deviceCountry : nil
    }

    /// A form for a new rule: the device's region suggests the method until a place says otherwise.
    static func new(deviceCountry: String?) -> PrayerForm {
        PrayerForm(draft: PrayerRuleDraft(countryCode: deviceCountry), deviceCountry: deviceCountry)
    }

    /// Picks a place (from the device, mode `device`, or a searched city, mode `manual`) and re-suggests the method for
    /// its country, unless the user already chose one themselves.
    mutating func choose(_ place: FoundPlace, mode: String) {
        draft.location = place.location(mode: mode)
        if !methodWasChosen {
            draft.applySuggestion(forCountry: place.countryCode)
            suggestedFor = place.countryCode ?? ""
        }
    }

    mutating func chooseMethod(_ key: String) {
        draft.method = key
        methodWasChosen = true
        suggestedFor = nil
    }

    mutating func togglePrayer(_ prayer: String) {
        if draft.prayers.contains(prayer) { draft.prayers.removeAll { $0 == prayer } } else { draft.prayers.append(prayer) }
    }

    func isOn(_ prayer: String) -> Bool { draft.prayers.contains(prayer) }

    /// "Suggested for the UK" under the method, while it is still the suggestion; `nil` once chosen by hand.
    func suggestionLine(locale: Locale = .current) -> String? {
        guard let code = suggestedFor, !code.isEmpty,
              PrayerMethodSuggestion.forCountry(code).method == draft.method,
              let name = locale.localizedString(forRegionCode: code) else { return nil }
        return "Suggested for \(Self.withArticle(name))"
    }

    private static func withArticle(_ country: String) -> String {
        switch country {
        case "United Kingdom": "the UK"
        case "United States": "the US"
        case "United Arab Emirates": "the UAE"
        case "Netherlands": "the Netherlands"
        default: country
        }
    }

    /// "Leicester · this iPhone" (a device place) or "Leicester" (a chosen city); "Choose where" with none yet.
    func locationLine(deviceName: String = "this iPhone") -> String {
        guard let place = draft.location else { return "Choose where" }
        let name = place.name ?? "Your location"
        return place.mode == "device" ? "\(name) · \(deviceName)" : name
    }

    /// What will appear today, under the form: "Starting now, today's Asr, Maghrib and Isha will appear. Fajr and Dhuhr
    /// have already closed, so they won't be added." `nil` with no place.
    func footnote(now: Date, boundary: DayBoundary) -> String? {
        guard draft.location != nil else { return nil }
        let chosen = ["fajr", "dhuhr", "asr", "maghrib", "isha"].filter(draft.prayers.contains)
        guard !chosen.isEmpty else { return nil }
        let coming = Set(PrayerEditing.upcomingToday(draft, now: now, boundary: boundary).map(\.prayer))
        let upcoming = chosen.filter(coming.contains).map(Self.name)
        let closed = chosen.filter { !coming.contains($0) }.map(Self.name)
        if closed.isEmpty { return "Today's \(Self.list(upcoming)) will appear." }
        if upcoming.isEmpty { return "Today's \(Self.list(closed)) \(closed.count == 1 ? "has" : "have") already closed, so they won't be added. Tomorrow's will appear." }
        return "Starting now, today's \(Self.list(upcoming)) will appear. \(Self.list(closed)) \(closed.count == 1 ? "has" : "have") already closed, so \(closed.count == 1 ? "it" : "they") won't be added."
    }

    static func name(_ prayer: String) -> String { prayer.prefix(1).uppercased() + prayer.dropFirst() }

    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    // MARK: Words for the rest of the form

    static func ishaEndsTitle(_ key: String) -> String { key == "fajr" ? "Fajr" : "Islamic midnight" }

    static func highLatitudeTitle(_ key: String) -> String {
        switch key {
        case "seventhOfNight": "Seventh of the night"
        case "twilightAngle": "Twilight angle"
        default: "Middle of the night"
        }
    }

    /// "Adjustments, high latitude" or, once something is set, what is set.
    var advancedSummary: String {
        let adjusted = draft.adjustments.filter { $0.value != 0 }.count
        if adjusted > 0 { return "\(adjusted) adjusted" }
        if draft.highLatitude != "middleOfNight" { return Self.highLatitudeTitle(draft.highLatitude) }
        return "Adjustments, high latitude"
    }

    /// "+2 min", "−3 min", "None".
    static func adjustment(_ minutes: Int) -> String {
        minutes == 0 ? "None" : "\(minutes > 0 ? "+" : "−")\(abs(minutes)) min"
    }

    mutating func stepAdjustment(_ prayer: String, by step: Int) {
        let next = max(-60, min(60, (draft.adjustments[prayer] ?? 0) + step))
        draft.adjustments[prayer] = next == 0 ? nil : next
    }

    static func message(for error: PrayerEditError) -> String {
        switch error {
        case .emptyTitle: "Give it a name first."
        case .noPrayers: "Pick at least one prayer."
        case .noLocation: "Choose where you are first, so the times can be worked out."
        case .adjustmentOutOfRange: "An adjustment can be up to an hour either way."
        case .unknownPrayer, .unknownMethod, .unknownOption: "Something in this form isn't one Jamaal knows. Check the choices."
        }
    }
}
