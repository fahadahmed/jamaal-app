import Foundation
import SwiftData

/// One habit window as Today shows it.
public struct TodayHabitRow {
    public var habit: Habit
    public var window: HabitTimeWindow
    /// The habit's title, with the window's label when the habit has several times a day ("Medication · Morning").
    public var title: String
    public var kind: HabitKind
    /// Logged today: a count, minutes or slips.
    public var amount: Int
    /// The count or minutes to reach, or an avoid habit's allowance of slips.
    public var target: Int
    public var isDone: Bool
}

/// A group, as a pill with a count; its habits live inside it, not among the rows.
public struct TodayHabitGroup {
    public var group: HabitGroup
    public var title: String
    public var rows: [TodayHabitRow]
    public var done: Int
    public var total: Int
}

/// The Habits part of Today (docs/journeys/today-list.md, item 4): groups first, then ungrouped habits by
/// window start (all-day last), then title. Paused, archived and not-scheduled habits aren't shown; a weekly-target
/// habit shows every day until its week's target is met, then as done.
public struct TodayHabits {
    public var groups: [TodayHabitGroup]
    public var rows: [TodayHabitRow]

    /// Windows done, out of windows due, across groups and rows ("Habits · 4 of 7").
    public var done: Int { groups.reduce(0) { $0 + $1.done } + rows.filter(\.isDone).count }
    public var total: Int { groups.reduce(0) { $0 + $1.total } + rows.count }

    @MainActor
    public static func read(
        in context: ModelContext, now: Date, boundary: DayBoundary, firstWeekday: Int = 1
    ) throws -> TodayHabits {
        let habitContext = HabitContext(
            boundary: boundary, today: boundary.logicalDate(at: now), firstWeekday: firstWeekday,
            engagedDays: try Engagement.engagedDays(in: context, boundary: boundary)
        )
        let due = HabitToday.dueWindows(of: try context.fetch(FetchDescriptor<Habit>()), context: habitContext)
        let rows = due.map { row(for: $0, today: habitContext.today) }.sorted(by: order)

        var grouped: [UUID: [TodayHabitRow]] = [:]
        var groups: [UUID: HabitGroup] = [:]
        var ungrouped: [TodayHabitRow] = []
        for row in rows {
            if let group = row.habit.group, !group.isArchived {
                grouped[group.id, default: []].append(row)
                groups[group.id] = group
            } else {
                ungrouped.append(row)
            }
        }
        let pills = groups.values
            .sorted { ($0.sortOrder, $0.title, $0.id.uuidString) < ($1.sortOrder, $1.title, $1.id.uuidString) }
            .map { group -> TodayHabitGroup in
                let members = grouped[group.id] ?? []
                return TodayHabitGroup(group: group, title: group.title, rows: members, done: members.filter(\.isDone).count, total: members.count)
            }
        return TodayHabits(groups: pills, rows: ungrouped)
    }

    private static func row(for due: DueWindow, today: CalendarDate) -> TodayHabitRow {
        let entry = (due.window.entries ?? []).filter { CalendarDate(storedDate: $0.date) == today }.max { $0.amount < $1.amount }
        let habit = due.habit
        let title = (habit.windows ?? []).count > 1 && !due.window.label.isEmpty ? "\(habit.title) · \(due.window.label)" : habit.title
        return TodayHabitRow(
            habit: habit, window: due.window, title: title, kind: habit.habitKind, amount: due.amountToday,
            target: max(habit.habitKind == .avoid ? 0 : 1, entry?.target ?? due.window.target), isDone: due.isDone
        )
    }

    /// Window start, all-day last, then title.
    private static func order(_ a: TodayHabitRow, _ b: TodayHabitRow) -> Bool {
        func key(_ r: TodayHabitRow) -> (Int, String, String) {
            let allDay = r.window.startMinute == 0 && r.window.endMinute >= 1439
            return (allDay ? Int.max : r.window.startMinute, r.title, r.window.id.uuidString)
        }
        return key(a) < key(b)
    }
}
