import Foundation
import SwiftData

public enum AnchorEditError: Error, Equatable, Sendable {
    case emptyTitle
    case noDays
    /// A rule needs at least one named time (or an all-day window).
    case noTime
    case badInterval
    /// With more than one time, each has a name ("Drop-off", "Pick-up").
    case slotNeedsALabel
    case windowTooShort
    case endsBeforeItStarts
    /// A one-off whose window has already closed.
    case endsInThePast
    /// A prayer or unreadable rule isn't edited here.
    case notAScheduledRule
}

/// How a scheduled rule repeats, as the form offers it (AN-05).
public enum AnchorRepeat: Equatable, Sendable {
    case days(Set<Int>)
    case everyNDays(Int)
    case everyNWeeks(Int, Set<Int>)
    /// An interval from the last time it was handled, not the calendar.
    case afterLast(minDays: Int, maxDays: Int)
}

/// One named time in a scheduled rule: a start and how long the window stays open, or all day.
public struct AnchorSlotDraft: Equatable, Sendable {
    public var id: String?
    public var label: String
    public var startMinute: Int
    public var windowMinutes: Int
    public var allDay: Bool

    public init(id: String? = nil, label: String = "", startMinute: Int = 8 * 60, windowMinutes: Int = 30, allDay: Bool = false) {
        self.id = id
        self.label = label
        self.startMinute = startMinute
        self.windowMinutes = windowMinutes
        self.allDay = allDay
    }
}

/// What the scheduled form collects (school run, bin night, plant watering, custom). The kind of rule is fixed once made.
public struct AnchorRuleDraft: Equatable {
    public var title = ""
    public var source: AnchorSource
    public var repeats: AnchorRepeat
    /// Where "every N days / weeks" counts from, or, for *after I last did it*, the day it was last handled.
    public var startDate: CalendarDate
    public var slots: [AnchorSlotDraft]
    public var effortMinutes: Int?
    public var placement: AnchorPlacement
    public var endDate: CalendarDate?
    public var remindAtStart = false
    public var remindBeforeEndMinutes: Int?

    /// The presets (docs/schema/anchor.md): placeholders, all editable.
    public static func preset(_ source: AnchorSource, today: CalendarDate) -> AnchorRuleDraft {
        switch source {
        case .schoolRun:
            return AnchorRuleDraft(
                title: "School run", source: .schoolRun, repeats: .days([1, 2, 3, 4, 5]), startDate: today,
                slots: [AnchorSlotDraft(label: "Drop-off", startMinute: 8 * 60 + 15, windowMinutes: 30)],
                effortMinutes: 30, placement: .fixed)
        case .binNight:
            return AnchorRuleDraft(
                title: "Bin night", source: .binNight, repeats: .days([3]), startDate: today,
                slots: [AnchorSlotDraft(label: "Bin night", startMinute: 19 * 60, windowMinutes: 180)],
                effortMinutes: 10, placement: .flexible)
        case .plantWatering:
            return AnchorRuleDraft(
                title: "Water the plants", source: .plantWatering, repeats: .afterLast(minDays: 3, maxDays: 4), startDate: today,
                slots: [AnchorSlotDraft(allDay: true)], effortMinutes: 10, placement: .flexible)
        case .custom, .prayerWindow, .unknown:
            return AnchorRuleDraft(
                title: "", source: .custom, repeats: .days([]), startDate: today, slots: [], effortMinutes: nil, placement: .fixed)
        }
    }

    /// "Due now": the last time it was handled was `minDays` ago, so the window opens today.
    public mutating func markDueNow(today: CalendarDate) {
        if case .afterLast(let minDays, _) = repeats { startDate = today.addingDays(-minDays) }
    }

    /// The form for an existing scheduled rule; `nil` for a prayer rule or one that can't be read.
    public init?(editing rule: AnchorRule) {
        guard case .scheduled(let config) = rule.config else { return nil }
        title = rule.title
        source = rule.source == .unknown ? .custom : rule.source
        effortMinutes = rule.effortMinutes
        placement = rule.placementKind == .unknown ? .fixed : rule.placementKind
        endDate = config.endDate
        remindAtStart = config.reminder?.atStart ?? false
        remindBeforeEndMinutes = config.reminder?.beforeEndMinutes
        slots = config.slots.map {
            AnchorSlotDraft(id: $0.id, label: $0.label, startMinute: $0.startMinute ?? 8 * 60, windowMinutes: $0.windowMinutes, allDay: $0.allDay)
        }
        let created = CalendarDate(storedDate: rule.createdAt)
        switch config.recurrence {
        case .weekly(let days): repeats = .days(Set(days)); startDate = created
        case .everyNDays(let n, let start): repeats = .everyNDays(n); startDate = start
        case .everyNWeeks(let n, let days, let start): repeats = .everyNWeeks(n, Set(days)); startDate = start
        case .afterLast(let minDays, let maxDays, let start): repeats = .afterLast(minDays: minDays, maxDays: maxDays); startDate = start
        }
    }

    private init(
        title: String, source: AnchorSource, repeats: AnchorRepeat, startDate: CalendarDate, slots: [AnchorSlotDraft],
        effortMinutes: Int?, placement: AnchorPlacement
    ) {
        self.title = title
        self.source = source
        self.repeats = repeats
        self.startDate = startDate
        self.slots = slots
        self.effortMinutes = effortMinutes
        self.placement = placement
    }
}

public enum AnchorEditing {

    /// Validates the draft and inserts the rule. Nothing is written when it is refused.
    @MainActor
    @discardableResult
    public static func create(_ draft: AnchorRuleDraft, in context: ModelContext, now: Date) throws -> AnchorRule {
        try validate(draft)
        let rule = AnchorRule(title: trimmed(draft.title))
        rule.createdAt = now
        context.insert(rule)
        apply(draft, to: rule, keepingExceptionsOf: nil)
        return rule
    }

    /// Applies the form to an existing scheduled rule, keeping its exceptions and each time's key (so Anchors already
    /// made for them stay theirs). Nothing is written when it is refused.
    @MainActor
    public static func update(_ rule: AnchorRule, with draft: AnchorRuleDraft, now: Date) throws {
        guard case .scheduled(let existing) = rule.config else { throw AnchorEditError.notAScheduledRule }
        try validate(draft)
        rule.title = trimmed(draft.title)
        apply(draft, to: rule, keepingExceptionsOf: existing)
    }

    // MARK: One-offs

    /// A one-off Anchor (a dentist appointment): no rule, stored on its day, with its window and optional reminders.
    @MainActor
    @discardableResult
    public static func createOneOff(
        title: String, on day: CalendarDate, startMinute: Int, endMinute: Int, effortMinutes: Int?,
        remindAtStart: Bool, remindBeforeEndMinutes: Int?, in context: ModelContext, boundary: DayBoundary, now: Date
    ) throws -> Anchor {
        let name = trimmed(title)
        guard !name.isEmpty else { throw AnchorEditError.emptyTitle }
        guard endMinute > startMinute else { throw AnchorEditError.endsBeforeItStarts }
        let start = boundary.instant(of: day, atMinute: startMinute)
        let end = boundary.instant(of: day, atMinute: endMinute)
        guard end > now else { throw AnchorEditError.endsInThePast }

        let anchor = Anchor(title: name)
        anchor.occurrenceDate = boundary.logicalDate(at: start).storedDate
        anchor.slotKey = ""
        anchor.windowStart = start
        anchor.windowEnd = end
        anchor.effortMinutes = effortMinutes.flatMap { $0 > 0 ? $0 : nil }
        anchor.generatedAt = now
        anchor.remindBeforeStartMinutes = remindAtStart ? 0 : nil
        anchor.remindBeforeEndMinutes = remindBeforeEndMinutes
        context.insert(anchor)
        return anchor
    }

    // MARK: Exceptions (AN-06)

    /// Adds a date range the rule skips (term break, holiday, travel, illness, other; the end can be open). It merges
    /// with any it overlaps. Attended, missed, skipped and delegated Anchors stay; pending ones inside it go at the next sync.
    @MainActor
    public static func addException(to rule: AnchorRule, from: CalendarDate, to: CalendarDate?, reason: ExceptionReason) throws {
        guard case .scheduled(var config) = rule.config else { throw AnchorEditError.notAScheduledRule }
        if let to, to < from { throw AnchorEditError.endsBeforeItStarts }
        var merged = AnchorException(from: from, to: to, reason: reason.storable ?? ExceptionReason.other.rawValue)
        var kept: [AnchorException] = []
        for existing in config.exceptions {
            let overlaps = (existing.to.map { merged.from <= $0 } ?? true) && (merged.to.map { existing.from <= $0 } ?? true)
            if overlaps {
                let end: CalendarDate? = (existing.to == nil || merged.to == nil) ? nil : max(existing.to!, merged.to!)
                merged = AnchorException(from: min(existing.from, merged.from), to: end, reason: existing.from <= from ? existing.reason : merged.reason)
            } else {
                kept.append(existing)
            }
        }
        config.exceptions = (kept + [merged]).sorted { $0.from < $1.from }
        rule.configData = config.json
    }

    @MainActor
    public static func removeException(from rule: AnchorRule, at index: Int) throws {
        guard case .scheduled(var config) = rule.config else { throw AnchorEditError.notAScheduledRule }
        guard config.exceptions.indices.contains(index) else { return }
        config.exceptions.remove(at: index)
        rule.configData = config.json
    }

    // MARK: Helpers

    private static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func validate(_ draft: AnchorRuleDraft) throws {
        guard !trimmed(draft.title).isEmpty else { throw AnchorEditError.emptyTitle }
        switch draft.repeats {
        case .days(let days):
            guard !days.filter({ (1...7).contains($0) }).isEmpty else { throw AnchorEditError.noDays }
        case .everyNDays(let n):
            guard n >= 1 else { throw AnchorEditError.badInterval }
        case .everyNWeeks(let n, let days):
            guard n >= 1 else { throw AnchorEditError.badInterval }
            guard !days.filter({ (1...7).contains($0) }).isEmpty else { throw AnchorEditError.noDays }
        case .afterLast(let minDays, let maxDays):
            guard minDays >= 1, maxDays >= minDays else { throw AnchorEditError.badInterval }
        }
        guard !draft.slots.isEmpty else { throw AnchorEditError.noTime }
        for slot in draft.slots {
            if draft.slots.count > 1 && trimmed(slot.label).isEmpty { throw AnchorEditError.slotNeedsALabel }
            if !slot.allDay && slot.windowMinutes < 1 { throw AnchorEditError.windowTooShort }
        }
        if let end = draft.endDate, end < draft.startDate { throw AnchorEditError.endsBeforeItStarts }
    }

    @MainActor
    private static func apply(_ draft: AnchorRuleDraft, to rule: AnchorRule, keepingExceptionsOf existing: ScheduledConfig?) {
        rule.source = draft.source
        rule.effortMinutes = draft.effortMinutes.flatMap { $0 > 0 ? $0 : nil }
        var isAfterLast = false
        let recurrence: AnchorRecurrence
        switch draft.repeats {
        case .days(let days): recurrence = .weekly(weekdays: days.filter { (1...7).contains($0) }.sorted())
        case .everyNDays(let n): recurrence = .everyNDays(n: n, startDate: draft.startDate)
        case .everyNWeeks(let n, let days): recurrence = .everyNWeeks(n: n, weekdays: days.filter { (1...7).contains($0) }.sorted(), startDate: draft.startDate)
        case .afterLast(let minDays, let maxDays):
            recurrence = .afterLast(minDays: minDays, maxDays: maxDays, startDate: draft.startDate)
            isAfterLast = true
        }
        rule.placementKind = isAfterLast ? .flexible : draft.placement                // an afterLast rule is always flexible

        var used = Set(draft.slots.compactMap(\.id))
        var counter = 0
        let slots = draft.slots.map { slot -> AnchorSlot in
            var id = slot.id
            if id == nil {
                repeat { counter += 1 } while used.contains("slot-\(counter)")
                id = "slot-\(counter)"
                used.insert(id!)
            }
            return AnchorSlot(
                id: id!, label: trimmed(slot.label), start: String(format: "%02d:%02d", slot.startMinute / 60, slot.startMinute % 60),
                windowMinutes: slot.allDay ? 0 : slot.windowMinutes, allDay: slot.allDay)
        }
        let reminder = (draft.remindAtStart || draft.remindBeforeEndMinutes != nil)
            ? AnchorReminder(atStart: draft.remindAtStart, beforeEndMinutes: draft.remindBeforeEndMinutes) : nil
        let config = ScheduledConfig(
            recurrence: recurrence, slots: slots, endDate: draft.endDate, reminder: reminder, exceptions: existing?.exceptions ?? [])
        rule.configData = config.json
    }
}
