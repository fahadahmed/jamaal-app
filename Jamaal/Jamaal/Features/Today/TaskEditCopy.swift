//
//  TaskEditCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words around editing a task in place: the undo toast, the future-task note and the pickers' helper lines.
enum TaskEditCopy {
    static let savedLabel = "Saved"
    static let moveToToday = "Move to today"
    static let effortOptions = [15, 30, 45, 60, 90, 120]
    static let effortHelper = "Two hours is a good most for one task. Anything bigger is easier to do as two, so consider splitting it."
    static let somedayNeedsADate = "Important and repeating tasks need a day. Lower its importance to park it."

    /// "Call the clinic back · now 30 min": the task and what changed. Several changes in one visit are counted.
    static func undoText(title: String, changes: [TaskChange]) -> String? {
        switch changes.count {
        case 0: nil
        case 1: "\(title) · \(phrase(changes[0]))"
        default: "\(title) · \(changes.count) changes"
        }
    }

    private static func phrase(_ change: TaskChange) -> String {
        switch change {
        case .title: "renamed"
        case .effort(let minutes): minutes.map { "now \(TaskDetailCopy.effort($0))" } ?? "no estimate"
        case .matters(let level): "now \(TaskDetailCopy.matters(level).lowercased())"
        case .due(let date): date.map { "now \(AddTaskForm.dateTitle($0))" } ?? "now someday"
        case .category(let name): name.map { "now \($0)" } ?? "no category"
        case .repeats(let kind):
            switch kind {
            case .daily: "now daily"
            case .weekly: "now weekly"
            case .monthly: "now monthly"
            case .off, .unknown: "no longer repeats"
            }
        }
    }

    /// Under a future task: it stays off Today, and off any day's capacity, until its day is planned.
    static func futureNote(for date: CalendarDate) -> String {
        "This counts toward \(PlanningCopy.weekday(date))'s capacity once you plan that day. It stays off Today until then."
    }

    // MARK: Repeat scope (TK-07)

    /// A change to a repeating task's template, with the values either side, for the scope sheet's sentence.
    enum ScopedChange {
        case effort(from: Int?, to: Int?)
        case matters(from: Importance, to: Importance)
        case category(from: String?, to: String?)
        case title(to: String)
    }

    static let scopeHero = ("Change just this one,", "or every one after?")
    static let scopeCancel = "Cancel"

    /// "Weekly on Monday", "Every day", "Monthly on the 22nd".
    static func scopeEyebrow(kind: RepeatKind, weekday: String?, dayOfMonth: Int?) -> String {
        switch kind {
        case .weekly: "Weekly on \(weekday ?? "the same day")"
        case .monthly: "Monthly on the \(ordinal(dayOfMonth ?? 1))"
        default: "Every day"
        }
    }

    private static func ordinal(_ n: Int) -> String {
        let suffix = switch (n % 100, n % 10) {
        case (11...13, _): "th"
        case (_, 1): "st"
        case (_, 2): "nd"
        case (_, 3): "rd"
        default: "th"
        }
        return "\(n)\(suffix)"
    }

    static func scopeSentence(_ change: ScopedChange) -> String {
        func effort(_ minutes: Int?) -> String { minutes.map(TaskDetailCopy.effort) ?? "no estimate" }
        switch change {
        case .effort(let from, let to): return "Effort goes from \(effort(from)) to \(effort(to))."
        case .matters(let from, let to): return "Matters goes from \(TaskDetailCopy.matters(from).lowercased()) to \(TaskDetailCopy.matters(to).lowercased())."
        case .category(let from, let to): return "Category goes from \(from ?? "none") to \(to ?? "none")."
        case .title(let to): return "The title becomes \u{201C}\(to)\u{201D}."
        }
    }

    static func scopeLater(kind: RepeatKind, weekday: String?) -> String {
        switch kind {
        case .weekly: "This and later \(weekday ?? "week")s"
        case .monthly: "This and later months"
        default: "This and every day after"
        }
    }

    static func scopeOnly(kind: RepeatKind, weekday: String?) -> String {
        switch kind {
        case .weekly: "Only this \(weekday ?? "week")"
        case .monthly: "Only this month"
        default: "Only this day"
        }
    }
}
