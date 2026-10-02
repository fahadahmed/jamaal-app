import Adhan
import Foundation

/// One prayer's window on a day.
public struct PrayerWindow: Equatable, Sendable {
    /// The slot key: `fajr`, `dhuhr`, `asr`, `maghrib` or `isha`.
    public var prayer: String
    /// What it is called on Today: the prayer's name, or *Jumu'ah* for Friday's Dhuhr when the rule says so.
    public var title: String
    public var start: Date
    public var end: Date
}

/// Prayer windows (docs/schema/anchor.md, "Prayer shape"), computed on-device with `adhan-swift`.
/// This is the only file that imports it.
///
/// Fajr runs to sunrise, Dhuhr to Asr, Asr to Maghrib, Maghrib to Isha, and Isha to Islamic midnight
/// (the midpoint between Maghrib and the next Fajr) or to the next Fajr. Adjustments shift each
/// prayer's computed start, and the windows derive from the adjusted times.
public enum PrayerWindows {

    /// The windows on `day` for the rule's chosen prayers, in order. Empty if the rule has no
    /// location or the library can't compute the day (extreme latitudes).
    public static func windows(config: PrayerConfig, on day: CalendarDate) -> [PrayerWindow] {
        guard let location = config.location,
              let times = prayerTimes(config: config, location: location, on: day) else { return [] }

        let ishaEnd: Date
        if config.ishaEnds == "fajr" {
            guard let next = prayerTimes(config: config, location: location, on: day.addingDays(1)) else { return [] }
            ishaEnd = next.fajr
        } else {
            guard let sunnah = SunnahTimes(from: times) else { return [] }
            ishaEnd = sunnah.middleOfTheNight
        }

        let all: [(key: String, start: Date, end: Date)] = [
            ("fajr", times.fajr, times.sunrise),
            ("dhuhr", times.dhuhr, times.asr),
            ("asr", times.asr, times.maghrib),
            ("maghrib", times.maghrib, times.isha),
            ("isha", times.isha, ishaEnd),
        ]
        let chosen = Set(config.prayers)
        return all.filter { chosen.contains($0.key) }.map { item in
            let isFriday = day.isoWeekday == 5
            let title = item.key == "dhuhr" && isFriday && config.fridayLabel ? "Jumu'ah" : item.key.prefix(1).uppercased() + item.key.dropFirst()
            return PrayerWindow(prayer: item.key, title: title, start: item.start, end: item.end)
        }
    }

    private static func prayerTimes(config: PrayerConfig, location: PrayerConfig.Location, on day: CalendarDate) -> PrayerTimes? {
        var method = CalculationMethod(rawValue: config.method) ?? .muslimWorldLeague
        if method == .other { method = .muslimWorldLeague }          // custom angles aren't offered
        var params = method.params
        params.madhab = config.madhab == "hanafi" ? .hanafi : .shafi
        params.highLatitudeRule = highLatitudeRule(config.highLatitude)
        let adjustments = config.adjustmentsMinutes
        params.adjustments = PrayerAdjustments(
            fajr: adjustments["fajr"] ?? 0, sunrise: 0, dhuhr: adjustments["dhuhr"] ?? 0,
            asr: adjustments["asr"] ?? 0, maghrib: adjustments["maghrib"] ?? 0, isha: adjustments["isha"] ?? 0
        )
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        return PrayerTimes(
            coordinates: Coordinates(latitude: location.latitude, longitude: location.longitude),
            date: components, calculationParameters: params
        )
    }

    private static func highLatitudeRule(_ name: String) -> HighLatitudeRule {
        switch name {
        case "seventhOfNight": .seventhOfTheNight
        case "twilightAngle": .twilightAngle
        default: .middleOfTheNight
        }
    }
}

/// The method and madhab to pre-select for a country (docs/schema/anchor.md, "Prayer method
/// suggestion"). The library has no region helper, so the table is bundled here. It only pre-selects
/// the form; the user can change both. **The owner should review it.**
public struct PrayerMethodSuggestion: Equatable, Sendable {
    public var method: String
    public var madhab: String

    private static let table: [String: PrayerMethodSuggestion] = {
        func s(_ method: String, _ madhab: String = "shafi") -> PrayerMethodSuggestion { PrayerMethodSuggestion(method: method, madhab: madhab) }
        var table: [String: PrayerMethodSuggestion] = [:]
        for code in ["US", "CA", "GB"] { table[code] = s("moonsightingCommittee") }
        table["SA"] = s("ummAlQura")
        table["AE"] = s("dubai")
        table["KW"] = s("kuwait")
        table["QA"] = s("qatar")
        for code in ["SG", "MY", "ID"] { table[code] = s("singapore") }
        table["TR"] = s("turkey", "hanafi")
        table["IR"] = s("tehran")
        table["EG"] = s("egyptian")
        for code in ["PK", "IN", "BD", "AF"] { table[code] = s("karachi", "hanafi") }
        return table
    }()

    /// The suggestion for an ISO country code (case-insensitive); anywhere else, or no code,
    /// is the Muslim World League with the standard Asr.
    public static func forCountry(_ code: String?) -> PrayerMethodSuggestion {
        let key = code?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        return table[key] ?? PrayerMethodSuggestion(method: "muslimWorldLeague", madhab: "shafi")
    }
}
