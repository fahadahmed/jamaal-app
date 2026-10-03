import Foundation

/// The hidden Eisenhower quadrant. Never shown to the user as a matrix or a label: it only drives
/// ordering, capacity filtering and prompts. (`doFirst` is from the v2 design; the other names are proposals.)
public enum Quadrant: Int, Sendable, Comparable {
    case doFirst = 0, schedule, fitIn, letGo

    public static func < (lhs: Quadrant, rhs: Quadrant) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Module 1: urgency, importance, the quadrant and the order Today shows
/// (docs/schema/task.md, "Derived, never stored").
public enum TaskPriority {

    /// A task due this many days from today, or sooner, is urgent. Tunable.
    static let urgencyWindowDays = 1
    /// `deferralCount` from which a task is stale (and counts as urgent).
    static let staleThreshold = 3
    /// `deferralCount` from which the engine suggests removing it.
    static let removalThreshold = 5

    /// Due tomorrow or earlier (overdue included), or deferred often enough to be stale.
    public static func isUrgent(_ task: TaskItem, today: CalendarDate) -> Bool {
        if isStale(task) { return true }
        guard let due = task.dueDate else { return false }
        return CalendarDate(storedDate: due) <= today.addingDays(urgencyWindowDays)
    }

    /// Medium or high. An importance this app doesn't recognise counts as low.
    public static func isImportant(_ task: TaskItem) -> Bool {
        task.importanceLevel == .medium || task.importanceLevel == .high
    }

    public static func quadrant(_ task: TaskItem, today: CalendarDate) -> Quadrant {
        switch (isImportant(task), isUrgent(task, today: today)) {
        case (true, true): .doFirst
        case (true, false): .schedule
        case (false, true): .fitIn
        case (false, false): .letGo
        }
    }

    public static func isStale(_ task: TaskItem) -> Bool { task.deferralCount >= staleThreshold }

    public static func suggestsRemoval(_ task: TaskItem) -> Bool { task.deferralCount >= removalThreshold }

    /// Today's order: quadrant, then due date (undated last), then the older task first. `low`
    /// tasks are never important, so they follow every medium and high task.
    public static func order(_ tasks: [TaskItem], today: CalendarDate) -> [TaskItem] {
        tasks.sorted { a, b in
            let (qa, qb) = (quadrant(a, today: today), quadrant(b, today: today))
            if qa != qb { return qa < qb }
            let (da, db) = (a.dueDate ?? .distantFuture, b.dueDate ?? .distantFuture)
            if da != db { return da < db }
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    // MARK: Prompts

    /// A plan of five or more tasks with fewer than two medium or high ones: "pick one or two that
    /// matter most". A prompt, never a block.
    public static func shouldPickPriorities(_ plan: [TaskItem]) -> Bool {
        plan.count >= 5 && plan.filter(isImportant).count < 2
    }

    /// Two or more `doFirst` tasks: "which matters most?".
    public static func hasMultipleDoFirst(_ tasks: [TaskItem], today: CalendarDate) -> Bool {
        tasks.filter { quadrant($0, today: today) == .doFirst }.count >= 2
    }
}
