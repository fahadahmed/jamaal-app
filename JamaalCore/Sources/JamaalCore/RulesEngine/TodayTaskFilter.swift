import Foundation

/// The category filter on Today (docs/journeys/today-list.md). It narrows the **Tasks** section only: Anchors and
/// habits have no category, and the meter, the load and *Also today* stay whole-day. It is local to a device and
/// never groups anything.
public enum TodayTaskFilter {

    /// `tasks` in the order given (the engine's), keeping those in `category`; `nil` keeps all. Categories are
    /// compared by identity, and a task with no category is hidden by any filter.
    public static func apply(_ tasks: [TaskItem], to category: TaskCategory?) -> [TaskItem] {
        guard let category else { return tasks }
        return tasks.filter { $0.category?.id == category.id }
    }

    /// What the filter menu offers: the active categories, in their own order.
    public static func options(_ categories: [TaskCategory]) -> [TaskCategory] {
        categories.filter { !$0.isArchived }.sorted { ($0.sortOrder, $0.name, $0.id.uuidString) < ($1.sortOrder, $1.name, $1.id.uuidString) }
    }
}
