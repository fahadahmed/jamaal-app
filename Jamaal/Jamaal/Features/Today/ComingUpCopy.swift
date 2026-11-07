//
//  ComingUpCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words on Today's **Coming up** row and the Coming up screen (UP-01). Plain and calm; nothing is urgent here, because
/// nothing here counts toward a day's capacity until that day is planned.
enum ComingUpCopy {
    static func rowTitle(count: Int) -> String {
        count == 0 ? "Coming up · nothing scheduled" : "Coming up · \(count) next 14 days"
    }

    /// "Tomorrow", "In 2 days" … "In 6 days", "Next week" (7 to 13 days), "In 2 weeks".
    static func howFar(daysAhead: Int) -> String {
        switch daysAhead {
        case ...1: "Tomorrow"
        case 2...6: "In \(daysAhead) days"
        case 7...13: "Next week"
        default: "In \(daysAhead / 7) weeks"
        }
    }

    /// "Fri 16 Oct".
    static func dayHeading(_ date: CalendarDate) -> String {
        let weekday = PlanningCopy.weekday(date).prefix(3)
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(weekday) \(date.day) \(months[date.month - 1])"
    }

    /// "45 min", "90 min", "1 h", "2 h"; `nil` when there is no estimate.
    static func effort(_ minutes: Int?) -> String? {
        guard let minutes else { return nil }
        return minutes % 60 == 0 && minutes >= 60 ? "\(minutes / 60) h" : "\(minutes) min"
    }

    static func anchorMeta(time: String) -> String { "\(time) · one-off Anchor" }

    static let note = "Tasks wait here until you plan their day. Nothing counts toward capacity yet."
    static func laterTitle(count: Int) -> String { "Later · \(count)" }
    static let empty = "Nothing scheduled yet. Give a task a later day and it waits here."
}
