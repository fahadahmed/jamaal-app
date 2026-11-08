//
//  DayReviewCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words on Day review (DY-01) and Today's Yesterday row. Plain counts in a calm voice: a day is described, never graded.
enum DayReviewCopy {
    /// "Mon 12 Oct".
    static func eyebrow(_ date: CalendarDate) -> String { ComingUpCopy.dayHeading(date) }

    /// Two lines, the second in italic accent: "A steady day. / Two of three done."
    static func hero(done: Int, planned: Int) -> (String, String) {
        switch (done, planned) {
        case (_, 0): ("A quiet day.", "No tasks on the list.")
        case (0, _): ("A slow day.", "Nothing ticked off.")
        case (1, 1): ("A full day.", "The one task done.")
        case let (d, p) where d == p: ("A full day.", "All \(word(d)) done.")
        default: ("A steady day.", "\(word(done, capitalised: true)) of \(word(planned)) done.")
        }
    }

    private static func word(_ n: Int, capitalised: Bool = false) -> String {
        let words = ["none", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        let text = n < words.count ? words[n] : "\(n)"
        return capitalised ? text.prefix(1).uppercased() + text.dropFirst() : text
    }

    static func used(usedMinutes: Int, budgetMinutes: Int) -> String { TodayCopy.meter(plannedMinutes: usedMinutes, budgetMinutes: budgetMinutes) }
    static func closed(time: String) -> String { "Closed \(time)" }

    static func anchorGroup(attended: Int, counted: Int) -> String { "\(attended) of \(counted) attended" }

    static func anchorOutcome(_ status: AttendanceStatus, time: String?) -> String {
        switch status {
        case .attended: time.map { "Attended \($0)" } ?? "Attended"
        case .missed: "Missed"
        case .skipped: "Skipped"
        case .delegated: "Someone else did it"
        default: "Not marked"
        }
    }

    static func habit(kind: HabitKind, state: DensityState, amount: Int, target: Int) -> String {
        switch kind {
        case .timed: "\(amount) of \(target) min"
        case .counted: "\(amount) of \(target)"
        case .avoid: state == .complete ? "Held" : "Slipped"
        default: state == .complete ? "Done" : "Not done"
        }
    }

    static func task(_ outcome: PastTaskOutcome, doneTime: String?) -> String {
        func day(_ date: CalendarDate?) -> String { date.map { eyebrow($0) } ?? "someday" }
        return switch outcome {
        case .done: doneTime.map { "Done \($0)" } ?? "Done"
        case .deferred(let to): "Deferred to \(day(to))"
        case .carried(let to): "Not done · carried to \(day(to))"
        case .notDone: "Not done"
        }
    }

    static func yesterdayRow(_ row: YesterdayRow) -> String? {
        switch row {
        case .hidden: nil
        case .notPlanned: "Yesterday · not planned"
        case .summary(let done, let planned): "Yesterday · \(done) of \(planned) done"
        }
    }

    static let footer = "Past days are read-only. A missed task can be ticked for two days."
    static let empty = "Nothing was recorded on this day."
}
