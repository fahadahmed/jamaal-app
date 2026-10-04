//
//  AnchorForm.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The Anchor form's own rules, apart from the view. Validating and writing is JamaalCore's `AnchorEditing`.
struct AnchorForm {
    var draft: AnchorRuleDraft
    let today: CalendarDate

    static let maxSlots = 6

    enum RepeatKind: CaseIterable { case days, everyNDays, everyNWeeks, afterLast }

    // MARK: Repeating

    var repeatKind: RepeatKind {
        switch draft.repeats {
        case .days: .days
        case .everyNDays: .everyNDays
        case .everyNWeeks: .everyNWeeks
        case .afterLast: .afterLast
        }
    }

    /// The weekdays the draft already has, so changing how it repeats keeps them.
    private var currentDays: Set<Int> {
        switch draft.repeats {
        case .days(let days), .everyNWeeks(_, let days): days.isEmpty ? [1, 2, 3, 4, 5] : days
        case .everyNDays, .afterLast: [1, 2, 3, 4, 5]
        }
    }

    mutating func chooseRepeat(_ kind: RepeatKind) {
        let days = currentDays
        switch kind {
        case .days: draft.repeats = .days(days)
        case .everyNDays: draft.repeats = .everyNDays(2)
        case .everyNWeeks: draft.repeats = .everyNWeeks(2, days)
        case .afterLast: draft.repeats = .afterLast(minDays: 3, maxDays: 4); draft.placement = .flexible
        }
        if kind == .afterLast, !draft.slots.contains(where: \.allDay) { draft.slots = [AnchorSlotDraft(allDay: true)] }
    }

    /// Adds or removes a weekday, but never leaves none.
    mutating func toggleDay(_ day: Int) {
        switch draft.repeats {
        case .days(var days): toggle(day, in: &days); draft.repeats = .days(days)
        case .everyNWeeks(let n, var days): toggle(day, in: &days); draft.repeats = .everyNWeeks(n, days)
        case .everyNDays, .afterLast: break
        }
    }

    private func toggle(_ day: Int, in days: inout Set<Int>) {
        if days.contains(day) { if days.count > 1 { days.remove(day) } } else { days.insert(day) }
    }

    mutating func stepInterval(by steps: Int) {
        switch draft.repeats {
        case .everyNDays(let n): draft.repeats = .everyNDays(min(60, max(1, n + steps)))
        case .everyNWeeks(let n, let days): draft.repeats = .everyNWeeks(min(8, max(1, n + steps)), days)
        case .days, .afterLast: break
        }
    }

    /// The shortest interval after last done; the longest follows it up so it is never shorter.
    mutating func stepMinDays(by steps: Int) {
        guard case .afterLast(let minDays, let maxDays) = draft.repeats else { return }
        let newMin = min(60, max(1, minDays + steps))
        draft.repeats = .afterLast(minDays: newMin, maxDays: max(maxDays, newMin))
    }

    mutating func stepMaxDays(by steps: Int) {
        guard case .afterLast(let minDays, let maxDays) = draft.repeats else { return }
        draft.repeats = .afterLast(minDays: minDays, maxDays: min(60, max(minDays, maxDays + steps)))
    }

    mutating func markDueNow() { draft.markDueNow(today: today) }
    mutating func markLastDoneToday() { draft.startDate = today }

    // MARK: Times

    var canAddSlot: Bool { draft.slots.count < Self.maxSlots && draft.repeats.isCalendarBased }
    var canRemoveSlot: Bool { draft.slots.count > 1 }

    private static let suggestions: [(label: String, start: Int)] = [("Pick-up", 15 * 60), ("Morning", 8 * 60), ("Afternoon", 14 * 60), ("Evening", 19 * 60), ("Later", 21 * 60), ("Night", 22 * 60)]

    mutating func addSlot() {
        guard canAddSlot else { return }
        let used = Set(draft.slots.map(\.label))
        let pick = Self.suggestions.first { !used.contains($0.label) } ?? ("Time \(draft.slots.count + 1)", 12 * 60)
        draft.slots.append(AnchorSlotDraft(label: pick.label, startMinute: pick.start, windowMinutes: draft.slots.first?.windowMinutes ?? 30))
    }

    mutating func removeSlot(at index: Int) {
        guard canRemoveSlot, draft.slots.indices.contains(index) else { return }
        draft.slots.remove(at: index)
    }

    static func stepWindow(_ slot: inout AnchorSlotDraft, by steps: Int) {
        slot.windowMinutes = min(480, max(5, slot.windowMinutes + steps * 5))
    }

    // MARK: Words

    static func summary(_ slot: AnchorSlotDraft) -> String {
        if slot.allDay { return "All day" }
        let length = slot.windowMinutes < 60 ? "\(slot.windowMinutes) min" : TodayCopy.duration(slot.windowMinutes)
        return "\(PlanningCopy.clock(slot.startMinute)) · \(length) window"
    }

    static func repeatTitle(_ kind: RepeatKind) -> String {
        switch kind {
        case .days: "On these days"
        case .everyNDays: "Every N days"
        case .everyNWeeks: "Every N weeks"
        case .afterLast: "After I last did it"
        }
    }

    static func reminderSummary(atStart: Bool, beforeEnd: Int?) -> String {
        switch (atStart, beforeEnd) {
        case (false, nil): "Off"
        case (true, nil): "At the start"
        case (false, let m?): "\(m) min before it closes"
        case (true, let m?): "At the start, and \(m) min before it closes"
        }
    }
}

extension AnchorRepeat {
    /// Calendar-based rules can have several times a day; an after-last rule is one all-day window.
    var isCalendarBased: Bool {
        if case .afterLast = self { return false }
        return true
    }
}
