//
//  TodayCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words and figures Today shows. Plain numbers, a calm voice, nothing that scolds. (The companion's
/// own phrasing arrives with the message-template layer; this is only the screen's fixed copy.)
enum TodayCopy {

    /// 135 → "2h 15m", 180 → "3h", 45 → "45m".
    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }

    static func meter(plannedMinutes: Int, budgetMinutes: Int) -> String {
        "\(duration(plannedMinutes)) of \(duration(budgetMinutes))"
    }

    static func stateWord(_ state: LoadState) -> String {
        switch state {
        case .light: "LIGHT"
        case .balanced: "BALANCED"
        case .full: "FULL"
        case .overloaded, .exhausting: "OVER"
        }
    }

    /// Overloaded and worse turn the meter terracotta; a full day is just full.
    static func isOver(_ state: LoadState) -> Bool { state.isOverloaded }

    private static let numberWords = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]

    /// "Four things," / "gently paced." — the second line is set in italic accent.
    static func headline(remaining: Int) -> (first: String, second: String) {
        guard remaining > 0 else { return ("A clear day", "to begin.") }
        let count = remaining < numberWords.count ? numberWords[remaining] : "\(remaining)"
        return ("\(count) \(remaining == 1 ? "thing" : "things"),", "gently paced.")
    }

    private static let weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    private static let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    /// "MON 12 MAY": the day's own label, in the user's logical date.
    static func headerLabel(_ date: CalendarDate) -> String {
        "\(weekdays[date.isoWeekday - 1]) \(date.day) \(months[date.month - 1])"
    }

    // MARK: The slider

    static let levels: [CapacityLevel] = [.low, .medium, .high]

    static func label(for level: CapacityLevel) -> String {
        switch level {
        case .low: "LOW"
        case .high: "HIGH"
        case .medium, .unknown: "MEDIUM"
        }
    }

    static func level(forStep step: Int) -> CapacityLevel { levels[min(max(step, 0), levels.count - 1)] }

    static func step(for level: CapacityLevel) -> Int { levels.firstIndex(of: level) ?? 1 }

    // MARK: Rows

    /// The parts of a task row's second line, before the category: how often it has slipped, and the estimate.
    static func taskMeta(deferrals: Int, effortMinutes: Int?) -> [String] {
        var parts: [String] = []
        switch deferrals {
        case ...0: break
        case 1: parts.append("Slipped once")
        case 2: parts.append("Slipped twice")
        default: parts.append("Slipped \(deferrals) times")
        }
        if let effortMinutes { parts.append("\(effortMinutes) min") }
        return parts
    }
}
