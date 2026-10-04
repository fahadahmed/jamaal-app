//
//  HabitForm.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The add / edit habit form's own rules, apart from the view: what each schedule choice does to the draft, adding
/// and removing times of day, stepping the target, and the words for a refusal. Validating and writing is JamaalCore's
/// `HabitEditing`.
struct HabitForm {
    var draft: HabitDraft

    enum Schedule: Equatable {
        case everyDay, weekdays
        case days(Set<Int>)
        case perWeek(Int)
    }

    // MARK: Schedule

    var schedule: Schedule {
        if draft.perWeek > 0 { return .perWeek(draft.perWeek) }
        if draft.weekdays == Set(1...7) { return .everyDay }
        if draft.weekdays == [1, 2, 3, 4, 5] { return .weekdays }
        return .days(draft.weekdays)
    }

    mutating func setSchedule(_ choice: Schedule) {
        switch choice {
        case .everyDay: draft.weekdays = Set(1...7); draft.perWeek = 0
        case .weekdays: draft.weekdays = [1, 2, 3, 4, 5]; draft.perWeek = 0
        case .days(let days): draft.weekdays = days; draft.perWeek = 0
        case .perWeek(let n): draft.perWeek = min(7, max(1, n))
        }
    }

    /// Adds or removes a day, but never leaves a habit with no days.
    mutating func toggleDay(_ day: Int) {
        var days = draft.weekdays
        if days.contains(day) { if days.count > 1 { days.remove(day) } } else { days.insert(day) }
        draft.weekdays = days
        draft.perWeek = 0
    }

    mutating func stepPerWeek(by steps: Int) { draft.perWeek = min(7, max(1, draft.perWeek + steps)) }

    // MARK: Target

    /// The count, minutes or allowance of the first time of day.
    mutating func stepTarget(by steps: Int) {
        guard !draft.windows.isEmpty else { return }
        let current = draft.windows[0].target
        let next: Int
        switch draft.kind {
        case .counted: next = min(99, max(1, current + steps))
        case .timed: next = min(480, max(5, current + steps * 5))
        case .avoid: next = min(20, max(0, current + steps))
        case .binary, .unknown: next = 1
        }
        for index in draft.windows.indices { draft.windows[index].target = next }      // every time of day shares it
    }

    static func targetTitle(kind: HabitKind, target: Int) -> String? {
        switch kind {
        case .counted: "\(target) times a day"
        case .timed: "\(target) minutes"
        case .avoid: target > 0 ? "Up to \(target) a day" : "None allowed"
        case .binary, .unknown: nil
        }
    }

    // MARK: Times of day

    private static let windowNames = ["Morning", "Evening", "Afternoon", "Night"]

    var canAddWindow: Bool { draft.windows.count < HabitEditing.maxWindows }

    /// A second time of day names the first "Morning" (if it was still all-day and unnamed) and adds "Evening";
    /// later ones take the next free name.
    mutating func addWindow() {
        guard canAddWindow else { return }
        if draft.windows.count == 1, draft.windows[0].label.isEmpty, draft.windows[0].startMinute == 0, draft.windows[0].endMinute == 1439 {
            draft.windows[0].label = "Morning"; draft.windows[0].startMinute = 6 * 60; draft.windows[0].endMinute = 12 * 60
        }
        let used = Set(draft.windows.map(\.label))
        let name = Self.windowNames.first { !used.contains($0) } ?? "Time \(draft.windows.count + 1)"
        draft.windows.append(HabitWindowDraft(
            label: name, startMinute: Self.hours(for: name).start, endMinute: Self.hours(for: name).end,
            target: draft.windows.first?.target ?? 1))
    }

    private static func hours(for name: String) -> (start: Int, end: Int) {
        switch name {
        case "Evening": (18 * 60, 23 * 60)
        case "Afternoon": (12 * 60, 18 * 60)
        case "Night": (21 * 60, 1439)
        default: (6 * 60, 12 * 60)
        }
    }

    func canRemoveWindow(at index: Int, withHistory history: Set<UUID>) -> Bool {
        guard draft.windows.count > 1, draft.windows.indices.contains(index) else { return false }
        return !(draft.windows[index].id.map(history.contains) ?? false)
    }

    mutating func removeWindow(at index: Int) {
        guard draft.windows.count > 1, draft.windows.indices.contains(index) else { return }
        draft.windows.remove(at: index)
    }

    static func summary(_ window: HabitWindowDraft) -> String {
        let hours = window.startMinute == 0 && window.endMinute == 1439 ? "All day" : "\(PlanningCopy.clock(window.startMinute))–\(PlanningCopy.clock(window.endMinute))"
        return window.reminderMinute.map { "\(hours) · remind \(PlanningCopy.clock($0))" } ?? hours
    }

    /// A `DatePicker` time of day, read back as a minute of the day in the person's own calendar.
    static func date(forMinute minute: Int, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: calendar.startOfDay(for: .now)) ?? .now
    }

    static func minute(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // MARK: Words

    static func question(_ kind: HabitKind) -> String {
        switch kind {
        case .binary, .unknown: "Did I do it?"
        case .counted: "Did I do it N times?"
        case .timed: "Did I do it for N minutes?"
        case .avoid: "Did I avoid it?"
        }
    }

    static func kindName(_ kind: HabitKind) -> String {
        switch kind {
        case .binary, .unknown: "Did I do it"
        case .counted: "Did I do it N times"
        case .timed: "Did I do it for N minutes"
        case .avoid: "Did I avoid it"
        }
    }

    static func hint(_ kind: HabitKind) -> String {
        switch kind {
        case .binary, .unknown: "Once is enough. Reading, a walk, medication."
        case .counted: "Counted with a stepper. Glasses of water, dhikr."
        case .timed: "Timed with Begin, like a task. Qur'an, a run."
        case .avoid: "Log a slip when it happens. Sugary drinks, late scrolling."
        }
    }

    static func message(for error: HabitEditError) -> String {
        switch error {
        case .emptyTitle: "Give it a name first."
        case .targetTooSmall: "The target needs to be at least one."
        case .noDays: "Pick at least one day, or choose a number of times a week."
        case .badWeeklyTarget: "A week has seven days: choose between one and seven."
        case .noWindow: "It needs at least one time of day."
        case .tooManyWindows: "Four times a day is the most."
        case .windowNeedsALabel: "Name each time of day, such as Morning or Evening."
        case .windowEndsBeforeItStarts: "A time of day has to end after it starts."
        case .windowHasHistory: "That time of day has history, so it stays. Archive the habit instead if you're done with it."
        }
    }
}
