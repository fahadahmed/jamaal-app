//
//  TaskDetailCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The detail sheet's table and the defer sheet's words. Plain facts and a calm voice.
enum TaskDetailCopy {

    static func effort(_ minutes: Int?) -> String {
        guard let minutes else { return "No estimate" }
        return minutes < 60 ? "\(minutes) min" : TodayCopy.duration(minutes)
    }

    static func matters(_ importance: Importance) -> String {
        switch importance {
        case .high: "High"
        case .medium: "Medium"
        case .low, .unknown: "Low"
        }
    }

    static func due(_ date: CalendarDate?, today: CalendarDate) -> String {
        guard let date else { return "Someday" }
        switch today.days(until: date) {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case ..<0: return "Overdue · \(AddTaskForm.dateTitle(date))"
        default: return AddTaskForm.dateTitle(date)
        }
    }

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func history(deferrals: Int, addedOn: CalendarDate) -> String {
        let added = "added \(addedOn.day) \(months[addedOn.month - 1])"
        switch deferrals {
        case ...0: return "Added \(addedOn.day) \(months[addedOn.month - 1])"
        case 1: return "Deferred once · \(added)"
        case 2: return "Deferred twice · \(added)"
        default: return "Deferred \(deferrals) times · \(added)"
        }
    }

    // MARK: Defer

    static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "First time"
        case 2: "Second time"
        case 3: "Third time"
        case 4: "Fourth time"
        case 5: "Fifth time"
        default: "\(n)th time"
        }
    }

    static func deferLine(_ preview: TaskDeferral.Preview) -> String {
        preview.suggestsRemoval
            ? "It's slipped \(preview.ordinal) times. Letting it go is fine too."
            : "This one keeps slipping. Pick a day that actually works."
    }

    /// "It was high, so it's eased to low. Someday is open now." — only when this deferral eases it.
    static func easeNote(_ preview: TaskDeferral.Preview) -> String? {
        guard preview.willEase, let from = preview.easesFrom else { return nil }
        return "It was \(matters(from).lowercased()), so it's eased to low. Someday is open now."
    }

    static let reasons: [(reason: DeferralReason, title: String)] = [
        (.tooMuch, "Too much on"), (.notReady, "Not ready"), (.noLonger, "Not relevant"),
    ]
}

/// The defer picker's choices (TK-03): a later day or Someday, and an optional reason.
struct DeferForm {
    let preview: TaskDeferral.Preview
    let today: CalendarDate
    let firstWeekdayISO: Int
    private(set) var target: CalendarDate?
    private(set) var reason: DeferralReason = .unspecified

    init(preview: TaskDeferral.Preview, today: CalendarDate, firstWeekdayISO: Int) {
        self.preview = preview
        self.today = today
        self.firstWeekdayISO = firstWeekdayISO
        self.target = today.addingDays(1)
    }

    /// Tomorrow, later this week, next week and (when allowed) Someday. Today isn't a deferral.
    var options: [QuickDate] {
        QuickDates.options(today: today, firstWeekday: firstWeekdayISO, importance: .low, repeating: false)
            .filter { $0.kind != .today && ($0.kind != .someday || preview.somedayAllowed) }
    }

    var isSomeday: Bool { target == nil }

    /// A later day only; anything else is ignored.
    mutating func choose(_ date: CalendarDate) {
        guard date > today else { return }
        target = date
    }

    mutating func chooseSomeday() {
        guard preview.somedayAllowed else { return }
        target = nil
    }

    mutating func toggleReason(_ new: DeferralReason) { reason = reason == new ? .unspecified : new }

    var moveTitle: String {
        guard let target else { return "Move to Someday" }
        let name = AddTaskForm.relativeButton(target, today: today)
        return "Move to \(name == "Tomorrow" ? "tomorrow" : name)"
    }
}
