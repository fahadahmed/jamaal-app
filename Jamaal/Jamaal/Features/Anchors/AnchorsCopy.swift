//
//  AnchorsCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The Anchors tab's words: a one-line summary per rule, its state, exceptions and the next Anchor.
enum AnchorsCopy {
    private static let short = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let plural = ["Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays", "Sundays"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "Mon–Fri", "Tuesdays", "Mon, Wed, Fri", "Every day".
    static func days(_ days: [Int]) -> String {
        let set = Set(days.filter { (1...7).contains($0) })
        let sorted = set.sorted()
        if set.count == 7 { return "Every day" }
        if sorted.count == 1 { return plural[sorted[0] - 1] }
        if sorted.count >= 3, sorted.last! - sorted.first! == sorted.count - 1 { return "\(short[sorted.first! - 1])–\(short[sorted.last! - 1])" }
        return sorted.map { short[$0 - 1] }.joined(separator: ", ")
    }

    private static func dayMonth(_ date: CalendarDate) -> String { "\(date.day) \(months[date.month - 1])" }
    private static func dayDate(_ date: CalendarDate) -> String { "\(short[date.isoWeekday - 1]) \(dayMonth(date))" }

    /// The line under a rule's name in the list.
    static func scheduleLine(_ config: ScheduledConfig, next: GeneratedAnchor?, today: CalendarDate, style: TodayCopy.TimeStyle = TodayCopy.TimeStyle()) -> String {
        var parts: [String] = []
        switch config.recurrence {
        case .weekly(let weekdays):
            parts.append(days(weekdays))
        case .everyNDays(let n, _):
            parts.append(n == 1 ? "Every day" : "Every \(n) days")
        case .everyNWeeks(let n, let weekdays, _):
            parts.append("Every \(n == 1 ? "week" : "\(n) weeks"), \(days(weekdays))")
        case .afterLast(let minDays, let maxDays, _):
            parts.append(minDays == maxDays ? "\(minDays) days after last" : "\(minDays)–\(maxDays) days after last")
            if let next {
                let last = next.windowEnd.addingTimeInterval(-1)
                parts.append("open until \(weekdayName(last, style: style))")
            }
            return parts.joined(separator: " · ")
        }
        parts.append(timesText(config.slots, style: style))
        if let next { parts.append("next \(nextWord(next, today: today, style: style))") }
        return parts.joined(separator: " · ")
    }

    private static func timesText(_ slots: [AnchorSlot], style: TodayCopy.TimeStyle) -> String {
        if slots.count == 1, let slot = slots.first {
            if slot.allDay { return "all day" }
            guard let start = slot.startMinute else { return "" }
            return "\(PlanningCopy.clock(start))–\(PlanningCopy.clock(min(start + slot.windowMinutes, 1439)))"
        }
        return slots.map { slot in
            slot.allDay ? slot.label.lowercased() : "\(slot.label.lowercased()) \(slot.start)"
        }.joined(separator: ", ")
    }

    private static func weekdayName(_ date: Date, style: TodayCopy.TimeStyle) -> String {
        date.formatted(Date.FormatStyle(locale: style.locale, timeZone: style.timeZone).weekday(.abbreviated))
    }

    private static func nextWord(_ next: GeneratedAnchor, today: CalendarDate, style: TodayCopy.TimeStyle) -> String {
        switch today.days(until: next.occurrenceDate) {
        case 0: "today"
        case 1: "tomorrow"
        default: weekdayName(next.windowStart, style: style)
        }
    }

    // MARK: State, exceptions

    /// "Paused · holiday · until Tue 2 Jun" or "Needs attention · …"; `nil` for a rule that is simply running.
    static func state(_ state: AnchorsOverview.State) -> String? {
        switch state {
        case .active: return nil
        case .paused(let reason, let until):
            let why = reason == .other || reason == .unknown ? "" : "\(reasonTitle(reason).lowercased()) · "
            return "Paused · \(why)\(until.map { "until \(dayDate($0))" } ?? "until you resume")"
        case .needsAttention(let why):
            return why == .newerVersion ? "Needs attention · update Jamaal to see it" : "Needs attention · this rule couldn't be read"
        }
    }

    static func reasonTitle(_ reason: ExceptionReason) -> String {
        switch reason {
        case .term: "Term break"
        case .holiday: "Holiday"
        case .travel: "Travel"
        case .illness: "Illness"
        case .other, .unknown: "Other"
        }
    }

    static func exception(_ exception: AnchorException) -> String {
        let reason = reasonTitle(exception.reasonKind)
        guard let to = exception.to else { return "\(reason) · from \(dayMonth(exception.from)), until you resume" }
        return to == exception.from ? "\(reason) · \(dayMonth(exception.from))" : "\(reason) · \(dayMonth(exception.from)) – \(dayMonth(to))"
    }

    /// One upcoming Anchor in a rule's detail: "Tomorrow · 08:15".
    static func upcoming(_ anchor: GeneratedAnchor, today: CalendarDate, style: TodayCopy.TimeStyle = TodayCopy.TimeStyle()) -> String {
        let day: String
        switch today.days(until: anchor.occurrenceDate) {
        case 0: day = "Today"
        case 1: day = "Tomorrow"
        default: day = dayDate(anchor.occurrenceDate)
        }
        return "\(day) · \(TodayCopy.time(anchor.windowStart, style: style))"
    }

    // MARK: Types and refusals

    static func typeTitle(_ source: AnchorSource) -> String {
        switch source {
        case .schoolRun: "School run"
        case .binNight: "Bin night"
        case .plantWatering: "Plant watering"
        case .custom, .prayerWindow, .unknown: "Something else"
        }
    }

    static func typeHint(_ source: AnchorSource) -> String {
        switch source {
        case .schoolRun: "Drop-off and pick-up on school days."
        case .binNight: "One evening a week."
        case .plantWatering: "Every few days, from when you last did it."
        case .custom, .prayerWindow, .unknown: "Anything with a time and a rhythm."
        }
    }

    static func message(for error: AnchorEditError) -> String {
        switch error {
        case .emptyTitle: "Give it a name first."
        case .noDays: "Pick at least one day."
        case .noTime: "Add at least one time."
        case .badInterval: "Check the numbers: an interval is at least one day, and the longest is never shorter than the shortest."
        case .slotNeedsALabel: "Name each time, such as Drop-off or Pick-up."
        case .windowTooShort: "A time needs a window of at least a minute."
        case .endsBeforeItStarts: "The end has to come after the start."
        case .endsInThePast: "That window has already closed."
        case .notAScheduledRule: "This kind of rule can't be edited here yet."
        }
    }
}
