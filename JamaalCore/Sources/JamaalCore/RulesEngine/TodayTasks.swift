import Foundation

/// The task part of Today.
public struct TodayTaskList {
    /// Live tasks due today or overdue that the capacity level shows, in the engine's order.
    public var shown: [TaskItem]
    /// Due tasks the level hides, collapsed under "Also today" with a count: nothing silently disappears.
    public var alsoToday: [TaskItem]
    /// Live tasks with no date.
    public var backlog: [TaskItem]
    /// Tasks completed today, still listed so finishing work doesn't make the list shrink away.
    public var completedToday: [TaskItem]
}

public enum TodayTasks {

    /// What Today shows for tasks at a capacity level (docs/architecture/rules-engine.md, module 7):
    /// **low** shows only urgent-and-important tasks; **medium** everything due except `letGo`;
    /// **high** everything due. Completed and dropped tasks are never live; a task due later isn't due.
    public static func list(_ tasks: [TaskItem], today: CalendarDate, level: CapacityLevel, boundary: DayBoundary) -> TodayTaskList {
        let live = tasks.filter { !$0.isCompleted && $0.droppedAt == nil }
        let due = live.filter { task in task.dueDate.map { CalendarDate(storedDate: $0) <= today } ?? false }

        var shown: [TaskItem] = []
        var hidden: [TaskItem] = []
        for task in TaskPriority.order(due, today: today) {
            let quadrant = TaskPriority.quadrant(task, today: today)
            let visible: Bool
            switch level {
            case .low: visible = quadrant == .doFirst
            case .high: visible = true
            case .medium, .unknown: visible = quadrant != .letGo
            }
            if visible { shown.append(task) } else { hidden.append(task) }
        }

        return TodayTaskList(
            shown: shown,
            alsoToday: hidden,
            backlog: live.filter { $0.dueDate == nil }.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) },
            completedToday: tasks
                .filter { $0.isCompleted && $0.completedAt.map(boundary.logicalDate(at:)) == today }
                .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        )
    }
}
