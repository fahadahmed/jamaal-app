import Foundation
import SwiftData

/// One row of Coming up: a future task, or a one-off Anchor.
public struct ComingUpItem {
    public enum Kind {
        case task(TaskItem)
        case oneOffAnchor(Anchor)
    }
    public var kind: Kind

    public var title: String {
        switch kind {
        case .task(let task): task.title
        case .oneOffAnchor(let anchor): anchor.title
        }
    }
    public var isOneOffAnchor: Bool {
        if case .oneOffAnchor = kind { return true }
        return false
    }
}

/// A day in the list, with how far ahead it is (1 = tomorrow) so the app can phrase "Tomorrow", "In 2 days", "Next week".
public struct ComingUpDay {
    public var date: CalendarDate
    public var daysAhead: Int
    public var items: [ComingUpItem]
}

/// Module 1's read model for **Coming up** (docs/journeys/coming-up-and-day-review.md): live tasks due after today
/// and one-off Anchors, by day for the next 14 days, then everything later. A task's `dueDate` is the day it is
/// scheduled for, so nothing here counts toward any day's capacity until that day is planned. Recurring Anchor
/// rules never appear (their windows are generated two days ahead); a repeating task shows its one live instance;
/// backlog tasks (no date) are not here.
public struct ComingUp {
    public static let horizonDays = 14

    /// Days with something on them, soonest first, within the next 14 days.
    public var days: [ComingUpDay]
    /// Beyond 14 days, soonest first (the collapsed *Later* section).
    public var later: [ComingUpItem]

    public init(days: [ComingUpDay] = [], later: [ComingUpItem] = []) {
        self.days = days
        self.later = later
    }

    /// The number on Today's row: items in the next 14 days.
    public var count: Int { days.reduce(0) { $0 + $1.items.count } }
    public var laterCount: Int { later.count }

    @MainActor
    public static func read(in context: ModelContext, today: CalendarDate, boundary: DayBoundary, keeping kept: Set<UUID> = []) throws -> ComingUp {
        read(tasks: try context.fetch(FetchDescriptor<TaskItem>()), anchors: try context.fetch(FetchDescriptor<Anchor>()), today: today, keeping: kept)
    }

    /// `keeping` names tasks that were ticked while the screen is open: they stay listed (struck through) so a tick can be
    /// taken back, and go when the screen is left. Done tasks are otherwise not here.
    public static func read(tasks: [TaskItem], anchors: [Anchor], today: CalendarDate, keeping kept: Set<UUID> = []) -> ComingUp {
        struct Entry { var day: CalendarDate; var order: (Int, Date, String); var item: ComingUpItem }
        var entries: [Entry] = []
        for task in tasks where (!task.isCompleted || kept.contains(task.id)) && task.droppedAt == nil {
            guard let due = task.dueDate.map({ CalendarDate(storedDate: $0) }), due > today else { continue }
            entries.append(Entry(day: due, order: (1, task.createdAt, task.id.uuidString), item: ComingUpItem(kind: .task(task))))
        }
        for anchor in anchors where anchor.rule == nil {
            let day = CalendarDate(storedDate: anchor.occurrenceDate)
            guard day > today, anchor.status == .pending else { continue }
            entries.append(Entry(day: day, order: (0, anchor.windowStart, anchor.id.uuidString), item: ComingUpItem(kind: .oneOffAnchor(anchor))))
        }
        entries.sort { ($0.day, $0.order.0, $0.order.1, $0.order.2) < ($1.day, $1.order.0, $1.order.1, $1.order.2) }

        var days: [ComingUpDay] = []
        var later: [ComingUpItem] = []
        for entry in entries {
            let ahead = today.days(until: entry.day)
            if ahead > horizonDays {
                later.append(entry.item)
            } else if let last = days.last, last.date == entry.day {
                days[days.count - 1].items.append(entry.item)
            } else {
                days.append(ComingUpDay(date: entry.day, daysAhead: ahead, items: [entry.item]))
            }
        }
        return ComingUp(days: days, later: later)
    }
}
