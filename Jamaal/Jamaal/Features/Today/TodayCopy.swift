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

    static func meter(plannedMinutes: Int, budgetMinutes: Int, wholeDay: Bool = false) -> String {
        let text = "\(duration(plannedMinutes)) of \(duration(budgetMinutes))"
        return wholeDay ? "\(text) · whole day" : text
    }

    // MARK: States, the filter and the carried-over row

    static let blankDay = "Your day is blank."
    static let allDone = "Nothing left for today."
    static func nothingIn(_ category: String) -> String { "Nothing in \(category) today." }

    /// "midnight" or a clock time like "03:00": when the day rolls over.
    static func closeTime(rolloverMinute: Int) -> String {
        rolloverMinute == 0 ? "midnight" : String(format: "%02d:%02d", rolloverMinute / 60, rolloverMinute % 60)
    }

    /// "Last night's session closed at midnight. 42 min logged on **Draft…**." in three parts, so the title can be bold.
    static func pickUp(minutes: Int, title: String, closedAt: String) -> (before: String, title: String, after: String) {
        let logged = minutes <= 0 ? "Under a minute" : "\(minutes) min"
        return ("Last night's session closed at \(closedAt). \(logged) logged on ", title, ".")
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

    /// "One" … "Ten", then digits ("13").
    static func countWord(_ n: Int) -> String { n >= 0 && n < numberWords.count ? numberWords[n] : "\(n)" }

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

    // MARK: Anchors

    /// How clock times and weekday names are written: the device's, unless a test says otherwise.
    struct TimeStyle {
        var timeZone: TimeZone = .current
        var locale: Locale = .current
    }

    static func time(_ date: Date, style: TimeStyle = TimeStyle()) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: style.locale, timeZone: style.timeZone))
    }

    private static func weekday(_ date: Date, style: TimeStyle) -> String {
        date.formatted(Date.FormatStyle(locale: style.locale, timeZone: style.timeZone).weekday(.wide))
    }

    /// The second line of a plain Anchor row.
    static func anchorDetail(
        status: AttendanceStatus, state: AnchorWindowState, windowStart: Date, windowEnd: Date,
        resolvedAt: Date?, effortMinutes: Int?, endsToday: Bool, style: TimeStyle = TimeStyle()
    ) -> String {
        switch status {
        case .attended: return resolvedAt.map { "Attended \(time($0, style: style))" } ?? "Attended"
        case .skipped: return "Not today"
        case .delegated: return "Someone else did it"
        case .missed: return "Window closed at \(time(windowEnd, style: style))"
        case .pending, .unknown:
            let until = endsToday ? time(windowEnd, style: style) : weekday(windowEnd.addingTimeInterval(-1), style: style)
            switch state {
            case .upcoming:
                let opens = "Opens at \(time(windowStart, style: style))"
                return effortMinutes.map { "\(opens) · \($0) min" } ?? opens
            case .open: return "Open until \(until)"
            case .closingSoon: return "Closing soon · until \(until)"
            case .closed: return "Window closed at \(time(windowEnd, style: style))"
            }
        }
    }

    /// The figure at the right of a plain Anchor row: the opening time while it is upcoming, "Day 2 of 3" for a
    /// window of several days, otherwise nothing.
    static func anchorTrailing(state: AnchorWindowState, windowStart: Date, dayNumber: Int, totalDays: Int, style: TimeStyle = TimeStyle()) -> String? {
        if totalDays > 1 { return "Day \(dayNumber) of \(totalDays)" }
        return state == .upcoming ? time(windowStart, style: style) : nil
    }

    static func groupCount(attended: Int, counting: Int) -> String { "\(attended)/\(counting)" }

    /// The second line of a grouped row: the next pending window, or a quiet done state.
    static func groupDetail(
        nextTitle: String?, nextState: AnchorWindowState?, nextStart: Date?, nextEnd: Date?, allDecided: Bool, style: TimeStyle = TimeStyle()
    ) -> String {
        guard let nextTitle, let nextState, let nextStart, let nextEnd else { return allDecided ? "All done for today" : "" }
        return nextState == .upcoming
            ? "\(nextTitle) · from \(time(nextStart, style: style))"
            : "\(nextTitle) · until \(time(nextEnd, style: style))"
    }

    static func title(for action: AnchorAction) -> String {
        switch action {
        case .attended: "Attended"
        case .notToday: "Not today"
        case .someoneElseDidIt: "Someone else did it"
        case .markDoneAfterAll: "Mark as done after all"
        case .undo: "Undo"
        }
    }

    // MARK: Habits

    /// The second line of a habit row, or `nil` when there is nothing to say yet (a binary habit not done).
    static func habitDetail(kind: HabitKind, amount: Int, target: Int, isDone: Bool) -> String? {
        switch kind {
        case .counted: return "\(amount) of \(target)"
        case .timed: return "\(amount) of \(target) min"
        case .binary, .unknown: return isDone ? "Done" : nil
        case .avoid:
            let slips = amount == 1 ? "1 slip" : "\(amount) slips"
            if isDone { return amount > 0 ? "Held today · \(slips)" : "Held today" }
            if amount == 0 { return target > 0 ? "None yet · up to \(target)" : "None yet · none allowed" }
            return amount <= target ? "\(amount) of \(target) · still within" : "\(slips) today"
        }
    }

    static func groupPill(done: Int, total: Int) -> String { "\(done) of \(total)" }

    static func habitsSummary(done: Int, total: Int) -> String { total == 0 ? "none today" : "\(done) of \(total) done" }
}
