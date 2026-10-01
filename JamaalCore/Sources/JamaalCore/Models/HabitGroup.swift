import Foundation
import SwiftData

/// A visual bundle of habits; no score of its own. See docs/schema/habit.md.
@Model
public final class HabitGroup {
    public var id: UUID = UUID()
    public var title: String = ""
    public var sortOrder: Int = 0
    public var isArchived: Bool = false
    public var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Habit.group) public var habits: [Habit]?

    public init(title: String = "") {
        self.title = title
    }
}
