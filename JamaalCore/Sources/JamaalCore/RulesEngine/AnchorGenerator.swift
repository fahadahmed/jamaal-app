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
        guard rule.isEnabled, !rule.isArchived,
              case .scheduled(let config) = rule.config, !config.recurrence.isAfterLast else { return [] }

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
            guard case .scheduled(let config) = rule.config, !config.recurrence.isAfterLast else { continue }
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
