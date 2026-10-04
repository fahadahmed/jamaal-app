import Foundation
import SwiftData

/// One habit window as the Habits tab reads it today.
public struct HabitWindowToday {
    public var window: HabitTimeWindow
    public var amount: Int
    public var target: Int
    public var isDone: Bool
}

/// One habit as a row of the Habits tab.
public struct HabitSummary {
    public var habit: Habit
    public var windows: [HabitWindowToday]
    /// A "N times a week" habit's week so far.
    public var weekly: WeeklyProgress?
    /// The pause covering today, if any (it says why, and when the habit resumes).
    public var pause: HabitPause?
    public var isPaused: Bool { pause != nil }
}

/// A group as an expandable card: its habits, today's count and a 14-day aggregate.
public struct HabitGroupSummary {
    public var group: HabitGroup
    public var habits: [HabitSummary]
    public var doneToday: Int
    public var dueToday: Int
    /// The last 14 days, oldest first: complete when every window was, partial by the share that were, missed when none were.
    public var grid: [DensityCell]
}

/// The Habits tab: groups, ungrouped habits, and what is archived (kept, with its history, and restorable).
public struct HabitsOverview {
    public var groups: [HabitGroupSummary]
    public var ungrouped: [HabitSummary]
    public var archived: [Habit]

    public static let aggregateDays = 14

    @MainActor
    public static func read(in context: ModelContext, now: Date, boundary: DayBoundary, firstWeekday: Int = 1) throws -> HabitsOverview {
        let habitContext = HabitContext(
            boundary: boundary, today: boundary.logicalDate(at: now), firstWeekday: firstWeekday,
            engagedDays: try Engagement.engagedDays(in: context, boundary: boundary))
        let all = try context.fetch(FetchDescriptor<Habit>())
        let live = all.filter { !$0.isArchived }.sorted { ($0.createdAt, $0.title, $0.id.uuidString) < ($1.createdAt, $1.title, $1.id.uuidString) }
        let summaries = live.map { summary(of: $0, context: habitContext) }

        var byGroup: [UUID: [HabitSummary]] = [:]
        var groups: [UUID: HabitGroup] = [:]
        var ungrouped: [HabitSummary] = []
        for item in summaries {
            if let group = item.habit.group, !group.isArchived {
                byGroup[group.id, default: []].append(item)
                groups[group.id] = group
            } else {
                ungrouped.append(item)
            }
        }
        let groupSummaries = groups.values
            .sorted { ($0.sortOrder, $0.title, $0.id.uuidString) < ($1.sortOrder, $1.title, $1.id.uuidString) }
            .map { group -> HabitGroupSummary in
                let members = byGroup[group.id] ?? []
                let windows = members.filter { !$0.isPaused }.flatMap(\.windows)
                return HabitGroupSummary(
                    group: group, habits: members, doneToday: windows.filter(\.isDone).count, dueToday: windows.count,
                    grid: aggregate(members.map(\.habit), context: habitContext))
            }
        return HabitsOverview(
            groups: groupSummaries, ungrouped: ungrouped,
            archived: all.filter(\.isArchived).sorted { ($0.title, $0.id.uuidString) < ($1.title, $1.id.uuidString) })
    }

    // MARK: Pieces

    @MainActor
    private static func summary(of habit: Habit, context: HabitContext) -> HabitSummary {
        let today = context.today
        let windows = (habit.windows ?? [])
            .sorted { ($0.startMinute, $0.label, $0.id.uuidString) < ($1.startMinute, $1.label, $1.id.uuidString) }
            .map { window -> HabitWindowToday in
                let entry = HabitWindowAccess.entry(of: window, on: today)
                let amount = entry?.amount ?? 0
                let target = max(habit.habitKind == .avoid ? 0 : 1, entry?.target ?? window.target)
                let done = habit.habitKind == .avoid ? entry?.completedAt != nil : amount >= max(1, target)
                return HabitWindowToday(window: window, amount: amount, target: target, isDone: done)
            }
        return HabitSummary(
            habit: habit, windows: windows, weekly: HabitSchedule.weeklyProgress(of: habit, on: today, context: context),
            pause: HabitPauses.active(habit, on: today))
    }

    private static func aggregate(_ habits: [Habit], context: HabitContext) -> [DensityCell] {
        (0..<aggregateDays).reversed().map { offset in
            let day = context.today.addingDays(-offset)
            let states = habits.flatMap { $0.windows ?? [] }
                .map { HabitDensity.state(of: $0, on: day, context: context) }
                .filter { $0 != .empty }
            guard !states.isEmpty else { return DensityCell(day: day, state: .empty) }
            let complete = states.filter { $0 == .complete }.count
            let state: DensityState
            if complete == states.count { state = .complete }
            else if complete == 0 && states.allSatisfy({ $0 == .missed }) { state = .missed }
            else if Double(complete) / Double(states.count) >= 0.5 { state = .partialHigh }
            else { state = .partialLow }
            return DensityCell(day: day, state: state)
        }
    }
}
