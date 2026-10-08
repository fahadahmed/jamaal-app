//
//  PlanningCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// Night Planning's words. Each step opens with a short statement (the last word set in italic accent), never a
/// verdict; numbers are plain.
enum PlanningCopy {
    typealias Headline = (plain: String, accent: String)

    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func weekday(_ date: CalendarDate) -> String { weekdays[date.isoWeekday - 1] }

    static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }

    static func eyebrow(position: Int, count: Int, step: PlanningStep, mode: PlanningMode = .evening) -> String {
        let name: String
        switch step {
        case .review: name = "REVIEW"
        case .carry: name = "CARRY"
        case .build: name = "BUILD"
        case .load: name = "LOAD"
        case .close, .unknown: name = "CLOSE"
        }
        return mode == .morning ? "THIS MORNING · \(position) OF \(count)" : "\(position) OF \(count) · \(name)"
    }

    // MARK: The wide canvas's step rail

    static func railTitle(_ step: PlanningStep, mode: PlanningMode) -> String {
        switch step {
        case .review: "Review today"
        case .carry: "Carry forward"
        case .build: mode == .morning ? "Build today" : "Build tomorrow"
        case .load: "Check the load"
        case .close, .unknown: mode == .morning ? "Set the day" : "Close the day"
        }
    }

    static func railEyebrow(for date: CalendarDate, mode: PlanningMode) -> String {
        mode == .morning ? "THIS MORNING" : "PLANNING \(weekday(date).uppercased())"
    }

    /// While the step is open: what is left to settle. Once it is behind: what was decided (what was left untouched is kept).
    static func carryRail(pending: Int, moved: Int, dropped: Int, settled: Bool) -> String {
        guard settled else { return pending > 0 ? "\(pending) to settle" : "All settled" }
        var parts: [String] = []
        if pending > 0 { parts.append("\(pending) kept") }
        if moved > 0 { parts.append("\(moved) moved") }
        if dropped > 0 { parts.append("\(dropped) dropped") }
        return parts.isEmpty ? "Nothing to settle" : parts.joined(separator: " · ")
    }

    static func buildRail(tasks: Int, minutes: Int) -> String {
        guard tasks > 0 else { return "Nothing yet" }
        let count = "\(tasks) \(tasks == 1 ? "task" : "tasks")"
        return minutes > 0 ? "\(count) · \(TodayCopy.duration(minutes))" : count
    }

    // MARK: Headlines

    static func reviewHeadline(date: CalendarDate) -> Headline { ("How \(weekday(date))", "went.") }

    static func carryHeadline(count: Int) -> Headline { ("\(TodayCopy.countWord(count)) didn't", "happen.") }

    static func buildHeadline(date: CalendarDate, mode: PlanningMode = .evening) -> Headline {
        mode == .morning ? ("Today's", "shape.") : ("\(weekday(date))'s", "shape.")
    }

    static func buildLede(dayStartMinute: Int, dayEndMinute: Int, freeMinutes: Int, mode: PlanningMode = .evening) -> String {
        mode == .morning
            ? "Until \(clock(dayEndMinute)). About \(TodayCopy.duration(freeMinutes)) free."
            : "\(clock(dayStartMinute)) to \(clock(dayEndMinute)). About \(TodayCopy.duration(freeMinutes)) of it is free."
    }

    static func tasksLabel(date: CalendarDate, mode: PlanningMode) -> String {
        mode == .morning ? "Tasks for today" : "Tasks for \(weekday(date))"
    }

    static func skipTitle(_ mode: PlanningMode) -> String { mode == .morning ? "Not now" : "Skip tonight" }

    static func loadHeadline(_ state: LoadState) -> Headline {
        switch state {
        case .light: ("Plenty of", "room.")
        case .balanced: ("About", "right.")
        case .full: ("Quite", "full.")
        case .overloaded, .exhausting: ("A little", "much.")
        }
    }

    // MARK: Review

    static func tasksRow(done: Int, left: Int) -> String { "\(done) done · \(left) left" }

    static func timeRow(actualMinutes: Int, estimatedMinutes: Int) -> String? {
        guard actualMinutes > 0 else { return nil }
        return "\(TodayCopy.duration(actualMinutes)) · estimated \(TodayCopy.duration(estimatedMinutes))"
    }

    static func habitsRow(done: Int, due: Int, partial: String?) -> String? {
        guard due > 0 else { return nil }
        let base = "\(done) of \(due)"
        return partial.map { "\(base) · \($0)" } ?? base
    }

    // MARK: Carry

    static func carryMeta(effortMinutes: Int?, deferrals: Int) -> String {
        var parts: [String] = []
        if let effortMinutes { parts.append("\(effortMinutes) min") }
        switch deferrals {
        case ...0: break
        case 1: parts.append("slipped once")
        case 2: parts.append("slipped twice")
        default: parts.append("slipped \(deferrals) times")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Load

    static func levelLine(date: CalendarDate, usual: CapacityLevel, freeMinutes: Int, suggested: CapacityLevel) -> String {
        let usualName = TodayCopy.label(for: usual).lowercased()
        let suggestedName = TodayCopy.label(for: suggested).lowercased()
        let fit = suggested == usual || (usual == .unknown && suggested == .medium) ? "\(suggestedName) fits." : "\(suggestedName) would fit better."
        return "\(weekday(date))s are usually \(usualName). With \(TodayCopy.duration(freeMinutes)) free, \(fit)"
    }

    static func overflow(minutes: Int, dayEndMinute: Int) -> String {
        let amount = minutes < 60 ? "\(minutes) min" : TodayCopy.duration(minutes)
        return "\(amount) past \(clock(dayEndMinute))"
    }

    private static func dayPhrase(_ date: CalendarDate, today: CalendarDate) -> String {
        let ahead = today.days(until: date)
        return (1...6).contains(ahead) ? weekday(date) : "\(date.day) \(months[date.month - 1])"
    }

    static func moveOffer(title: String, target: CalendarDate?, today: CalendarDate) -> String {
        guard let target else { return "\(title) could wait. Want me to pick a day for it?" }
        return "\(title) could wait until \(dayPhrase(target, today: today)). Want me to move it?"
    }

    static func moveButton(target: CalendarDate?) -> String {
        guard let target else { return "Pick a day" }
        return "Move to \(weekday(target).prefix(3))"
    }

    // MARK: Close

    static func closeLine(tasks: Int, minutes: Int, firstAnchor: String?) -> String {
        guard tasks > 0 else { return "Nothing planned, and that's fine. Put the phone down." }
        var line = "\(TodayCopy.countWord(tasks)) \(tasks == 1 ? "task" : "tasks"), \(TodayCopy.duration(minutes))."
        if let firstAnchor { line += " \(firstAnchor) is first." }
        return line + " Put the phone down."
    }

    static func closeHeadline(_ mode: PlanningMode) -> String { mode == .morning ? "Today is set." : "Tomorrow is ready." }
    static func closeAction(_ mode: PlanningMode) -> String { mode == .morning ? "Open Today" : "Good night" }

    /// "Two tasks, 1h 45m, at medium. The school run is first." (the morning has no phone to put down).
    static func morningCloseLine(tasks: Int, minutes: Int, level: CapacityLevel, firstAnchor: String?) -> String {
        guard tasks > 0 else { return "Nothing planned, and that's fine." }
        var line = "\(TodayCopy.countWord(tasks)) \(tasks == 1 ? "task" : "tasks"), \(TodayCopy.duration(minutes)), at \(TodayCopy.label(for: level).lowercased())."
        if let firstAnchor { line += " \(firstAnchor) is first." }
        return line
    }

    static func nightsPlanned(_ n: Int) -> String { "\(n) \(n == 1 ? "night" : "nights") planned" }
}
