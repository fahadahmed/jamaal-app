//
//  AddTaskForm.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The add sheet's state and rules, kept apart from the view so they can be tested: what the chips offer, what
/// choosing one does to the rest, and what the button says. Creating the task is JamaalCore's `TaskCreation`.
struct AddTaskForm {
    var draft = TaskDraft()
    let today: CalendarDate
    /// The calendar's first weekday as an ISO weekday (Monday = 1 … Sunday = 7).
    let firstWeekdayISO: Int

    init(today: CalendarDate, firstWeekdayISO: Int, dueDate: CalendarDate? = nil) {
        self.today = today
        self.firstWeekdayISO = firstWeekdayISO
        draft.dueDate = dueDate
    }

    var canSubmit: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// An important or repeating task needs a date, so Someday isn't offered for it.
    private var needsDate: Bool { draft.importance == .medium || draft.importance == .high || draft.repeatKind != .off }

    var dueOptions: [QuickDate] {
        QuickDates.options(today: today, firstWeekday: firstWeekdayISO, importance: draft.importance, repeating: draft.repeatKind != .off)
    }

    /// Raising importance to medium or high dates an undated task today; an existing date is kept, and lowering never clears one.
    mutating func setImportance(_ level: Importance) {
        draft.importance = level
        if needsDate && draft.dueDate == nil { draft.dueDate = today }
    }

    mutating func setRepeat(_ kind: RepeatKind) {
        draft.repeatKind = kind
        if needsDate && draft.dueDate == nil { draft.dueDate = today }
    }

    /// `nil` is Someday, which is refused while the task needs a date.
    mutating func choose(_ date: CalendarDate?) {
        if date == nil && needsDate { return }
        draft.dueDate = date
    }

    // MARK: Effort

    static let effortShortcuts = [15, 30, 60, 120]

    /// The four shortcuts, plus the chosen value as its own chip when it isn't one of them ("3h 30m").
    var effortChips: [Int] {
        guard let minutes = draft.effortMinutes, !Self.effortShortcuts.contains(minutes) else { return Self.effortShortcuts }
        return Self.effortShortcuts + [minutes]
    }

    /// The "Other…" stepper: 15-minute steps from 15 minutes to 8 hours, starting from the preselected 30.
    mutating func stepEffort(by steps: Int) {
        let next = (draft.effortMinutes ?? 30) + steps * 15
        draft.effortMinutes = min(480, max(15, next))
    }

    static func effortTitle(_ minutes: Int) -> String {
        minutes == 120 ? "2h+" : TodayCopy.duration(minutes)
    }

    // MARK: Words

    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func dateTitle(_ date: CalendarDate) -> String {
        "\(weekdays[date.isoWeekday - 1].prefix(3)) \(date.day) \(months[date.month - 1])"
    }

    /// "today", "tomorrow", a weekday within the coming week, else "19 Oct".
    private func phrase(for date: CalendarDate) -> String {
        Self.relativeName(date, today: today) ?? "\(date.day) \(Self.months[date.month - 1])"
    }

    private static func relativeName(_ date: CalendarDate, today: CalendarDate) -> String? {
        switch today.days(until: date) {
        case 0: "today"
        case 1: "tomorrow"
        case 2...6: weekdays[date.isoWeekday - 1]
        default: nil
        }
    }

    var buttonTitle: String {
        guard let due = draft.dueDate else { return "Add to someday" }
        return "Add for \(phrase(for: due))"
    }

    /// The offer button's label: "Tomorrow", "Wednesday", or "19 Oct".
    static func relativeButton(_ date: CalendarDate, today: CalendarDate) -> String {
        relativeName(date, today: today).map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "\(date.day) \(months[date.month - 1])"
    }

    /// The Day-is-full panel: the figures including the new task, and the offer.
    static func dayFullCopy(
        _ check: DayFullCheck, adding minutes: Int, on day: CalendarDate, today: CalendarDate
    ) -> (title: String, detail: String) {
        func name(_ d: CalendarDate) -> String { relativeName(d, today: today).map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? dateTitle(d) }
        let figures = "\(name(day)) is at \(TodayCopy.duration(check.plannedMinutes + minutes)) of \(TodayCopy.duration(check.budgetMinutes))."
        guard let suggestion = check.suggestion else { return ("Day is full", figures) }
        let offered = name(suggestion)
        let spoken = relativeName(suggestion, today: today) ?? dateTitle(suggestion)
        return ("Day is full — put it on \(spoken)?", "\(figures) \(offered) has room.")
    }
}
