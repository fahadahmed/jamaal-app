import Foundation
import SwiftData

/// An Anchor instance a rule would generate: the dry-run shape, before it is stored.
public struct GeneratedAnchor: Equatable, Sendable {
    public var title: String
    public var occurrenceDate: CalendarDate
    public var slotKey: String
    public var windowStart: Date
    public var windowEnd: Date
    public var effortMinutes: Int?
    public var remindBeforeStartMinutes: Int?
    public var remindBeforeEndMinutes: Int?
}

/// What a sync changed.
public struct AnchorSyncReport: Equatable, Sendable {
    public var created = 0
    public var updated = 0
    public var removed = 0
    public init(created: Int = 0, updated: Int = 0, removed: Int = 0) {
        self.created = created
        self.updated = updated
        self.removed = removed
    }
}

/// Module 3, generation (docs/schema/anchor.md, docs/architecture/rules-engine.md): turns rules into
/// window-bound instances keyed by `(rule, occurrenceDate, slotKey)`. This slice covers the
/// scheduled family's calendar recurrences; `afterLast` and prayer windows follow.
public enum AnchorGenerator {

    // MARK: Preview — pure, no writes

    /// The instances `rule` would produce on `days`: the generator as a dry run, used by the rule's
    /// detail and by reminder scheduling. A disabled, archived or unreadable rule produces none.
    ///
    /// An instance is never created for a window that ended before the rule existed.
    public static func preview(rule: AnchorRule, days: [CalendarDate], boundary: DayBoundary) -> [GeneratedAnchor] {
        guard rule.isEnabled, !rule.isArchived, case .scheduled(let config) = rule.config else { return [] }
        if config.recurrence.isAfterLast { return afterLastPreview(rule: rule, config: config, days: days, boundary: boundary) }

        var result: [GeneratedAnchor] = []
        for day in days where config.isActive(on: day) && config.recurrence.occurs(on: day) {
            for slot in config.slots {
                guard let window = window(for: slot, on: day, boundary: boundary) else { continue }
                if window.end <= rule.createdAt { continue }
                result.append(GeneratedAnchor(
                    title: slot.label.isEmpty ? rule.title : slot.label,
                    occurrenceDate: boundary.logicalDate(at: window.start),
                    slotKey: slot.id,
                    windowStart: window.start,
                    windowEnd: window.end,
                    effortMinutes: rule.effortMinutes,
                    remindBeforeStartMinutes: (config.reminder?.atStart ?? false) ? 0 : nil,
                    remindBeforeEndMinutes: config.reminder?.beforeEndMinutes
                ))
            }
        }
        return result
    }

    // MARK: afterLast — an interval from the last time it was handled

    /// The next `afterLast` window for a slot, or `nil` if one is still live or none can open.
    ///
    /// There is exactly one live instance per slot, always all-day. With none yet, the first opens
    /// `minDays` after `startDate` (the date it was last handled); a start older than the rule is
    /// treated as due now. After an attended, skipped or delegated instance the next opens `minDays`
    /// after the logical day it was handled; after a missed one it opens the following day and
    /// stays open for the same length, so a missed watering isn't pushed a further 3 days away.
    /// No window opens inside an exception (the clock pauses) or after the end date.
    ///
    /// `now` lets a pending instance whose window has closed count as missed before it is stored so.
    static func afterLastWindow(
        rule: AnchorRule, slot: AnchorSlot, config: ScheduledConfig, boundary: DayBoundary, now: Date?
    ) -> GeneratedAnchor? {
        guard case .afterLast(let minDays, let maxDays, let startDate) = config.recurrence else { return nil }
        let length = maxDays - minDays + 1
        let latest = (rule.anchors ?? []).filter { $0.slotKey == slot.id }.max { $0.windowStart < $1.windowStart }

        var open: CalendarDate
        if let latest {
            let closedPending = latest.status == .pending && now.map { latest.windowEnd <= $0 } == true
            if latest.status == .pending && !closedPending { return nil }               // a live one exists
            if latest.status == .missed || closedPending {
                open = boundary.logicalDate(at: latest.windowEnd)
            } else {
                open = boundary.logicalDate(at: latest.resolvedAt ?? latest.windowEnd).addingDays(minDays)
            }
        } else {
            open = startDate.addingDays(minDays)
            if boundary.startInstant(of: open.addingDays(length)) <= rule.createdAt {
                open = boundary.logicalDate(at: rule.createdAt)
            }
        }

        var steps = 0
        while let exception = config.exceptions.first(where: { $0.covers(open) }) {
            guard let end = exception.to, steps < 1000 else { return nil }
            open = end.addingDays(1)
            steps += 1
        }
        if let endDate = config.endDate, open > endDate { return nil }

        return GeneratedAnchor(
            title: slot.label.isEmpty ? rule.title : slot.label,
            occurrenceDate: open,
            slotKey: slot.id,
            windowStart: boundary.startInstant(of: open),
            windowEnd: boundary.startInstant(of: open.addingDays(length)),
            effortMinutes: rule.effortMinutes,
            remindBeforeStartMinutes: (config.reminder?.atStart ?? false) ? 0 : nil,
            remindBeforeEndMinutes: config.reminder?.beforeEndMinutes
        )
    }

    /// The live window (or, if none, the projected next one) wherever it overlaps `days`.
    private static func afterLastPreview(rule: AnchorRule, config: ScheduledConfig, days: [CalendarDate], boundary: DayBoundary) -> [GeneratedAnchor] {
        var result: [GeneratedAnchor] = []
        for slot in config.slots {
            let live = (rule.anchors ?? []).filter { $0.slotKey == slot.id && $0.status == .pending }.max { $0.windowStart < $1.windowStart }
            let item: GeneratedAnchor?
            if let live {
                item = GeneratedAnchor(
                    title: live.title, occurrenceDate: CalendarDate(storedDate: live.occurrenceDate), slotKey: live.slotKey,
                    windowStart: live.windowStart, windowEnd: live.windowEnd, effortMinutes: live.effortMinutes,
                    remindBeforeStartMinutes: live.remindBeforeStartMinutes, remindBeforeEndMinutes: live.remindBeforeEndMinutes
                )
            } else {
                item = afterLastWindow(rule: rule, slot: slot, config: config, boundary: boundary, now: nil)
            }
            guard let item else { continue }
            let overlaps = days.contains { day in
                item.windowStart < boundary.startInstant(of: day.addingDays(1)) && item.windowEnd > boundary.startInstant(of: day)
            }
            if overlaps { result.append(item) }
        }
        return result
    }

    private static func window(for slot: AnchorSlot, on day: CalendarDate, boundary: DayBoundary) -> (start: Date, end: Date)? {
        if slot.allDay {
            return (boundary.startInstant(of: day), boundary.startInstant(of: day.addingDays(1)))
        }
        guard let minute = slot.startMinute, slot.windowMinutes >= 1 else { return nil }
        let start = boundary.instant(of: day, atMinute: minute)
        return (start, start.addingTimeInterval(Double(slot.windowMinutes) * 60))
    }

    // MARK: Sync — writes today and tomorrow

    /// Brings the stored instances for the next `horizonDays` days (today and tomorrow by default) in
    /// line with the rules, idempotently:
    ///
    /// - a missing instance is created, a **pending** one that differs is updated in place;
    /// - a pending one no rule produces any more (an exception, a removed slot or weekday) is removed;
    /// - **a decided one** (attended, missed, skipped, delegated) is never touched, and a decided
    ///   instance holds its key, so a skipped one is never resurrected;
    /// - a disabled or archived rule loses its future pending instances;
    /// - a rule that needs attention is left alone entirely, and one-offs are never touched.
    @MainActor
    public static func sync(in context: ModelContext, boundary: DayBoundary, now: Date, horizonDays: Int = 2) throws -> AnchorSyncReport {
        var report = AnchorSyncReport()
        let today = boundary.logicalDate(at: now)
        let horizon = (0..<max(1, horizonDays)).map { today.addingDays($0) }

        for rule in try context.fetch(FetchDescriptor<AnchorRule>()) {
            guard case .scheduled(let config) = rule.config else { continue }
            if config.recurrence.isAfterLast {
                try syncAfterLast(rule: rule, config: config, in: context, boundary: boundary, now: now, report: &report)
                continue
            }
            let existing = rule.anchors ?? []

            guard rule.isEnabled, !rule.isArchived else {
                for anchor in existing where anchor.status == .pending && CalendarDate(storedDate: anchor.occurrenceDate) >= today {
                    context.delete(anchor)
                    report.removed += 1
                }
                continue
            }

            func key(_ date: CalendarDate, _ slot: String) -> String { "\(date.isoString)|\(slot)" }
            let desired = preview(rule: rule, days: horizon, boundary: boundary)
            let desiredKeys = Set(desired.map { key($0.occurrenceDate, $0.slotKey) })
            var byKey: [String: Anchor] = [:]
            for anchor in existing { byKey[key(CalendarDate(storedDate: anchor.occurrenceDate), anchor.slotKey)] = anchor }

            for item in desired {
                if let anchor = byKey[key(item.occurrenceDate, item.slotKey)] {
                    if anchor.status == .pending, apply(item, to: anchor) { report.updated += 1 }
                } else {
                    let anchor = Anchor(title: item.title)
                    anchor.occurrenceDate = item.occurrenceDate.storedDate
                    anchor.slotKey = item.slotKey
                    anchor.generatedAt = now
                    context.insert(anchor)
                    anchor.rule = rule
                    _ = apply(item, to: anchor)
                    report.created += 1
                }
            }
            for anchor in existing where anchor.status == .pending {
                let date = CalendarDate(storedDate: anchor.occurrenceDate)
                if horizon.contains(date), !desiredKeys.contains(key(date, anchor.slotKey)) {
                    context.delete(anchor)
                    report.removed += 1
                }
            }
        }
        if report != AnchorSyncReport() { try context.save() }
        return report
    }

    /// `afterLast` rules keep exactly one live instance per slot, created as soon as the previous one
    /// is resolved (or closed). A disabled or archived rule loses its live pending window, as does a
    /// slot that was removed or a window that opens inside a new exception; decided ones stay.
    @MainActor
    private static func syncAfterLast(
        rule: AnchorRule, config: ScheduledConfig, in context: ModelContext,
        boundary: DayBoundary, now: Date, report: inout AnchorSyncReport
    ) throws {
        let slotIDs = Set(config.slots.map(\.id))
        var removedAny = false
        for anchor in rule.anchors ?? [] where anchor.status == .pending {
            let opensInException = config.isExcepted(CalendarDate(storedDate: anchor.occurrenceDate))
            let disabled = !rule.isEnabled || rule.isArchived
            if (disabled && anchor.windowEnd > now) || !slotIDs.contains(anchor.slotKey) || opensInException {
                context.delete(anchor)
                report.removed += 1
                removedAny = true
            }
        }
        if removedAny { try context.save() }
        guard rule.isEnabled, !rule.isArchived else { return }

        for slot in config.slots {
            guard let item = afterLastWindow(rule: rule, slot: slot, config: config, boundary: boundary, now: now) else { continue }
            let anchor = Anchor(title: item.title)
            anchor.occurrenceDate = item.occurrenceDate.storedDate
            anchor.slotKey = item.slotKey
            anchor.generatedAt = now
            context.insert(anchor)
            anchor.rule = rule
            _ = apply(item, to: anchor)
            report.created += 1
        }
        if report.created > 0 || removedAny { try context.save() }
    }

    /// Copies a generated instance's fields onto an Anchor; `true` if anything changed.
    private static func apply(_ item: GeneratedAnchor, to anchor: Anchor) -> Bool {
        var changed = false
        func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<Anchor, T>, _ value: T) {
            if anchor[keyPath: keyPath] != value { anchor[keyPath: keyPath] = value; changed = true }
        }
        set(\.title, item.title)
        set(\.windowStart, item.windowStart)
        set(\.windowEnd, item.windowEnd)
        set(\.effortMinutes, item.effortMinutes)
        set(\.remindBeforeStartMinutes, item.remindBeforeStartMinutes)
        set(\.remindBeforeEndMinutes, item.remindBeforeEndMinutes)
        return changed
    }
}
