import Foundation
import SwiftData

/// One Anchor as Today shows it. Derived from the clock; nothing here is stored.
public struct TodayAnchorRow {
    public var anchor: Anchor
    /// The rule's title with the slot label when it differs ("School run · Drop-off"); a one-off's own title.
    public var title: String
    public var state: AnchorWindowState
    /// The status to show: a pending Anchor whose window has closed reads as missed at once.
    public var status: AttendanceStatus
    /// How far through its window it is, 0…1 (the window bar).
    public var progress: Double
    /// For a window of several days ("Day 2 of 3"): today's place in it, and how many days it spans.
    public var dayNumber: Int
    public var totalDays: Int
    /// The window's last day is today ("Open until 15:32" rather than "until Wednesday").
    public var endsToday: Bool
}

/// A rule that yields several Anchors today, shown as one collapsed row. Display-only: it has no state of
/// its own, and everything else reads the individual instances.
public struct TodayAnchorGroup {
    public var title: String
    public var members: [TodayAnchorRow]
    /// Attended, out of `counting`. Skipped and delegated leave the denominator; missed stays in it.
    public var attended: Int
    public var counting: Int
    /// The first member still pending, in window order.
    public var next: TodayAnchorRow?
    public var isAllDecided: Bool
}

public enum TodayAnchorItem {
    case plain(TodayAnchorRow)
    case group(TodayAnchorGroup)
}

/// The Anchors part of Today (docs/journeys/today-list.md, item 3). Anchors are always shown, at every level.
public enum TodayAnchors {

    @MainActor
    public static func items(in context: ModelContext, now: Date, boundary: DayBoundary) throws -> [TodayAnchorItem] {
        let today = boundary.logicalDate(at: now)
        let todays = try context.fetch(FetchDescriptor<Anchor>()).filter { isOnToday($0, today: today, boundary: boundary) }
        let rows = todays
            .map { row(for: $0, now: now, today: today, boundary: boundary) }
            .sorted { ($0.anchor.windowStart, $0.title, $0.anchor.id.uuidString) < ($1.anchor.windowStart, $1.title, $1.anchor.id.uuidString) }

        var items: [TodayAnchorItem] = []
        var grouped = Set<UUID>()
        for row in rows {
            guard let rule = row.anchor.rule else { items.append(.plain(row)); continue }
            let siblings = rows.filter { $0.anchor.rule?.id == rule.id }
            if siblings.count > 1 {
                if grouped.insert(rule.id).inserted { items.append(.group(group(rule: rule, members: siblings))) }
            } else {
                items.append(.plain(row))
            }
        }
        return items                                    // a group sits where its first member does: earliest start
    }

    /// Today's by `occurrenceDate`, plus a pending multi-day window (plants) that opened earlier and is still open.
    private static func isOnToday(_ anchor: Anchor, today: CalendarDate, boundary: DayBoundary) -> Bool {
        let occurrence = CalendarDate(storedDate: anchor.occurrenceDate)
        if occurrence == today { return true }
        guard occurrence < today, anchor.status == .pending else { return false }
        return lastDay(of: anchor, boundary: boundary) >= today
    }

    private static func lastDay(of anchor: Anchor, boundary: DayBoundary) -> CalendarDate {
        boundary.logicalDate(at: anchor.windowEnd.addingTimeInterval(-1))
    }

    private static func row(for anchor: Anchor, now: Date, today: CalendarDate, boundary: DayBoundary) -> TodayAnchorRow {
        let state = AnchorAttendance.windowState(of: anchor, at: now)
        let length = anchor.windowEnd.timeIntervalSince(anchor.windowStart)
        let progress = length > 0 ? min(1, max(0, now.timeIntervalSince(anchor.windowStart) / length)) : (state == .closed ? 1 : 0)
        let firstDay = boundary.logicalDate(at: anchor.windowStart)
        let last = lastDay(of: anchor, boundary: boundary)
        return TodayAnchorRow(
            anchor: anchor, title: title(of: anchor), state: state,
            status: AnchorAttendance.displayStatus(of: anchor, at: now), progress: progress,
            dayNumber: max(1, firstDay.days(until: today) + 1), totalDays: max(1, firstDay.days(until: last) + 1),
            endsToday: last == today
        )
    }

    private static func title(of anchor: Anchor) -> String {
        guard let rule = anchor.rule, !rule.title.isEmpty, anchor.title != rule.title, !anchor.title.isEmpty else {
            return anchor.title.isEmpty ? (anchor.rule?.title ?? "") : anchor.title
        }
        return "\(rule.title) · \(anchor.title)"
    }

    private static func group(rule: AnchorRule, members: [TodayAnchorRow]) -> TodayAnchorGroup {
        // A grouped row lists its members by slot label ("Fajr, Dhuhr…"); the rule's title is the group's.
        let members = members.map { member -> TodayAnchorRow in
            var member = member
            member.title = member.anchor.title.isEmpty ? rule.title : member.anchor.title
            return member
        }
        let counting = members.filter { $0.status != .skipped && $0.status != .delegated }
        return TodayAnchorGroup(
            title: rule.title, members: members,
            attended: counting.filter { $0.status == .attended }.count, counting: counting.count,
            next: members.first { $0.status == .pending },
            isAllDecided: members.allSatisfy { $0.status != .pending }
        )
    }

    // MARK: Acting on a row

    /// What can be done with an Anchor right now (docs/journeys/walkthroughs/04-anchors.md, AN-10).
    public static func actions(for anchor: Anchor, now: Date, boundary: DayBoundary) -> [AnchorAction] {
        let state = AnchorAttendance.windowState(of: anchor, at: now)
        switch AnchorAttendance.displayStatus(of: anchor, at: now) {
        case .pending:
            return state == .upcoming ? [.notToday, .someoneElseDidIt] : [.attended, .notToday, .someoneElseDidIt]
        case .attended, .skipped, .delegated:
            return state == .closed ? [] : [.undo]
        case .missed:
            return boundary.logicalDate(at: now) == boundary.logicalDate(at: anchor.windowEnd) ? [.markDoneAfterAll] : []
        case .unknown:
            return []
        }
    }

    /// Does it. Throws `AnchorAttendance.LogError` when the rules refuse (and changes nothing).
    public static func perform(_ action: AnchorAction, on anchor: Anchor, now: Date, boundary: DayBoundary) throws {
        switch action {
        case .attended: try AnchorAttendance.attend(anchor, at: now)
        case .notToday: try AnchorAttendance.skip(anchor, at: now)
        case .someoneElseDidIt: try AnchorAttendance.delegate(anchor, at: now)
        case .markDoneAfterAll: try AnchorAttendance.markDoneAfterAll(anchor, at: now, boundary: boundary)
        case .undo: try AnchorAttendance.undo(anchor, at: now)
        }
    }
}

public enum AnchorAction: Sendable, Hashable {
    case attended, notToday, someoneElseDidIt, markDoneAfterAll, undo
}
