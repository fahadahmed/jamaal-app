import Foundation
import SwiftData

/// The Anchors rules list (AN-01): each rule with its state and next Anchor, and what is archived.
public struct AnchorsOverview {

    public enum State: Equatable, Sendable {
        case active
        /// Inside an exception today: a term break, a holiday… and the last day of it (`nil`: until resumed).
        case paused(reason: ExceptionReason, until: CalendarDate?)
        /// Never generated and never deleted: "Update Jamaal to see it" or "couldn't be read".
        case needsAttention(NeedsAttentionReason)
    }

    public struct Row {
        public var rule: AnchorRule
        public var state: State
        /// The next Anchor the rule will make from now (its dry run), if any.
        public var next: GeneratedAnchor?
    }

    public var rows: [Row]
    public var archived: [AnchorRule]

    /// How far ahead "next" looks.
    public static let horizonDays = 28

    @MainActor
    public static func read(in context: ModelContext, now: Date, boundary: DayBoundary) throws -> AnchorsOverview {
        let today = boundary.logicalDate(at: now)
        let all = try context.fetch(FetchDescriptor<AnchorRule>())
        let live = all.filter { !$0.isArchived }.sorted { ($0.createdAt, $0.title, $0.id.uuidString) < ($1.createdAt, $1.title, $1.id.uuidString) }
        let rows = live.map { rule -> Row in
            let state = state(of: rule, today: today)
            let next = AnchorGenerator
                .preview(rule: rule, days: (0..<horizonDays).map { today.addingDays($0) }, boundary: boundary)
                .filter { $0.windowEnd > now }
                .min { ($0.windowStart, $0.slotKey) < ($1.windowStart, $1.slotKey) }
            return Row(rule: rule, state: state, next: next)
        }
        return AnchorsOverview(
            rows: rows, archived: all.filter(\.isArchived).sorted { ($0.title, $0.id.uuidString) < ($1.title, $1.id.uuidString) })
    }

    /// The Anchors a rule would make over `days` days from `start`: the rule detail's upcoming list. No writes.
    public static func upcoming(_ rule: AnchorRule, from start: CalendarDate, days: Int, boundary: DayBoundary) -> [GeneratedAnchor] {
        AnchorGenerator.preview(rule: rule, days: (0..<max(0, days)).map { start.addingDays($0) }, boundary: boundary)
            .sorted { ($0.windowStart, $0.slotKey) < ($1.windowStart, $1.slotKey) }
    }

    private static func state(of rule: AnchorRule, today: CalendarDate) -> State {
        switch rule.config {
        case .needsAttention(let reason): return .needsAttention(reason)
        case .prayer(let config):
            if let exception = config.exceptions.first(where: { $0.covers(today) }) { return .paused(reason: exception.reasonKind, until: exception.to) }
            return .active
        case .scheduled(let config):
            if let exception = config.exceptions.first(where: { $0.covers(today) }) { return .paused(reason: exception.reasonKind, until: exception.to) }
            return .active
        }
    }
}
