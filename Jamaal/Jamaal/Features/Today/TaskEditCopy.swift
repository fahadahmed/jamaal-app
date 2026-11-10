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
}
