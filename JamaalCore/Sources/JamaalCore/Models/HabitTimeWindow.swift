import Foundation
import SwiftData

/// A time of day a habit is due. See docs/schema/habit.md.
@Model
public final class HabitTimeWindow {
    public var id: UUID = UUID()
    public var label: String = ""
    public var startMinute: Int = 0
    public var endMinute: Int = 1439
    public var target: Int = 1
    public var effortMinutes: Int? = nil
    public var reminderMinute: Int? = nil

    public var habit: Habit?
    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.window) public var entries: [HabitEntry]?
    @Relationship(deleteRule: .cascade, inverse: \WorkSession.habitWindow) public var sessions: [WorkSession]?

    public init() {
    }
}
