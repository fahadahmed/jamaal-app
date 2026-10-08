//
//  HabitsCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The Habits tab's words. Plain numbers, never a streak; a pause is a pause, not a lapse.
enum HabitsCopy {

    struct WindowStatus {
        var label: String
        var startMinute: Int
        var amount: Int
        var target: Int
        var isDone: Bool
    }

    struct PauseStatus {
        var reason: PauseReason
        /// The last paused day, or `nil` when the pause runs until the habit is resumed.
        var endsOn: CalendarDate?
    }

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static func reasonTitle(_ reason: PauseReason) -> String {
        switch reason {
        case .travel: "Travel"
        case .illness: "Illness"
        case .cycle: "Cycle"
        case .other, .unknown: "Other"
        }
    }

    /// The one line under a habit's name in the list.
    static func status(kind: HabitKind, windows: [WindowStatus], weekly: WeeklyProgress?, pause: PauseStatus?) -> String {
        if let pause {
            let reason = pause.reason == .other || pause.reason == .unknown ? "" : "\(reasonTitle(pause.reason).lowercased()) · "
            guard let end = pause.endsOn else { return "Paused · \(reason)until you resume" }
            let resume = end.addingDays(1)
            return "Paused · \(reason)resumes \(resume.day) \(months[resume.month - 1])"
        }
        if windows.count > 1 {
            let ordered = windows.sorted { $0.startMinute < $1.startMinute }
            let done = ordered.filter(\.isDone).map { "\($0.label) done" }
            guard let next = ordered.first(where: { !$0.isDone }) else { return "All done today" }
            return (done + ["\(next.label.lowercased()) at \(PlanningCopy.clock(next.startMinute))"]).joined(separator: " · ")
        }
        guard let window = windows.first else { return "" }
        if let weekly {
            switch kind {
            case .binary, .unknown: return "Done · \(weekly.done) of \(weekly.target) this week"
            case .counted: return "Counted · \(weekly.done) of \(weekly.target) this week"
            case .timed: return "Timed · \(weekly.done) of \(weekly.target) this week"
            case .avoid: return "Avoid · \(weekly.done) of \(weekly.target) this week"
            }
        }
        switch kind {
        case .counted: return "Counted · \(window.amount) of \(window.target) today"
        case .timed: return "Timed · \(window.amount) of \(window.target) min today"
        case .binary, .unknown: return window.isDone ? "Done today" : "Not yet today"
        case .avoid:
            if window.isDone { return "Avoid · held today" }
            return window.amount == 0 ? "Avoid · none today" : "Avoid · \(window.amount) \(window.amount == 1 ? "slip" : "slips") today"
        }
    }

    static func groupCount(done: Int, due: Int) -> String { due == 0 ? "nothing due today" : "\(done) of \(due) today" }

    static func archived(count: Int) -> String { "ARCHIVED · \(count)" }

    // MARK: Detail

    static func eyebrow(kind: HabitKind, target: Int, weekly: Int?) -> String {
        var text: String
        switch kind {
        case .counted: text = "COUNTED · \(target) A DAY"
        case .timed: text = "TIMED · \(target) MIN"
        case .avoid: text = target > 0 ? "AVOID · UP TO \(target)" : "AVOID · NONE ALLOWED"
        case .binary, .unknown: text = "DID IT"
        }
        if let weekly, weekly > 0 { text += " · \(weekly) A WEEK" }
        return text
    }

    static func schedule(weekdays: Set<Int>, perWeek: Int) -> String {
        if perWeek > 0 { return perWeek == 1 ? "Once a week" : "\(perWeek) a week" }
        let days = weekdays.filter { (1...7).contains($0) }
        if days.count == 7 { return "Every day" }
        if days == [1, 2, 3, 4, 5] { return "Weekdays" }
        if days == [6, 7] { return "Weekends" }
        return days.sorted().map { weekdayNames[$0 - 1] }.joined(separator: ", ")
    }

    /// The plain-language read: numbers first, a lighter schedule only as a question.
    static func read(_ read: DensityRead, kind: HabitKind) -> String {
        guard read.due > 0 else { return "Nothing to read yet. A week or so of days first." }
        let reached = kind == .avoid ? "Held on" : (kind == .counted || kind == .timed ? "Reached the target on" : "Done on")
        var text = "\(reached) \(read.completed) of \(read.due) days."
        if kind == .avoid { text += " Days nothing was logged stay empty — they aren't counted either way." }
        if read.suggestsLighterCadence { text += " That may be more than this season allows: try a lighter schedule?" }
        return text
    }
}
