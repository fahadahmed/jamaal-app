import Foundation

/// How loaded a day is, from `loadScore` (planned task minutes as a percentage of the budget).
/// Thresholds are from docs/architecture/rules-engine.md, module 7.
public enum LoadState: Sendable, Hashable, Codable {
    case light, balanced, full, overloaded, exhausting

    /// `< 70` light · `< 90` balanced · `< 110` full · `≤ 140` overloaded · beyond that exhausting.
    public init(score: Int) {
        switch score {
        case ..<70: self = .light
        case ..<90: self = .balanced
        case ..<110: self = .full
        case ...140: self = .overloaded
        default: self = .exhausting
        }
    }

    /// `true` for `overloaded` or worse: what `DayPlan.wasOverloaded` records.
    public var isOverloaded: Bool { self == .overloaded || self == .exhausting }
}

/// Module 7, the energy budget: the user's level gives a budget of *focused task minutes*.
/// (Free time, the other measure, is separate.)
public enum CapacityLoad {

    /// The task-minute budget for a level: medium is the user's normal day; low is ⅔ of it and
    /// high is 4⁄3, each rounded to the nearest 5 minutes so the number shown is the number used.
    /// An unknown level budgets as medium.
    public static func budgetMinutes(for level: CapacityLevel, mediumDayMinutes: Int) -> Int {
        switch level {
        case .low: roundedToFive(Double(mediumDayMinutes) * 2 / 3)
        case .high: roundedToFive(Double(mediumDayMinutes) * 4 / 3)
        case .medium, .unknown: mediumDayMinutes
        }
    }

    /// Planned minutes as a whole percentage of the budget (0 if there is no budget).
    public static func loadScore(plannedMinutes: Int, budgetMinutes: Int) -> Int {
        guard budgetMinutes > 0 else { return 0 }
        return Int((Double(plannedMinutes) * 100 / Double(budgetMinutes)).rounded())
    }

    private static func roundedToFive(_ minutes: Double) -> Int {
        Int((minutes / 5).rounded()) * 5
    }
}

extension UserSettings {
    /// The level a day uses when none was confirmed: this weekday's entry in `weekdayLevels`
    /// (ISO weekday, Monday = 1), or `medium` if it isn't listed or the map can't be read.
    public func defaultLevel(forISOWeekday weekday: Int) -> CapacityLevel {
        guard
            let data = weekdayLevels.data(using: .utf8),
            let map = try? JSONSerialization.jsonObject(with: data) as? [String: String],
            let raw = map[String(weekday)]
        else { return .medium }
        let level = CapacityLevel(stored: raw)
        return level.isUnknown ? .medium : level
    }

    /// Sets one weekday's default level, keeping the others. An unreadable map starts from the
    /// weekend defaults (Saturday and Sunday `low`) rather than losing them.
    public func setDefaultLevel(_ level: CapacityLevel, forISOWeekday weekday: Int) {
        guard let raw = level.storable else { return }
        var map: [String: String] = ["6": "low", "7": "low"]
        if let data = weekdayLevels.data(using: .utf8),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            map = existing
        }
        map[String(weekday)] = raw
        if let data = try? JSONSerialization.data(withJSONObject: map, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            weekdayLevels = text
        }
    }
}
