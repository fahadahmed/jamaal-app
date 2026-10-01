import Foundation
import SwiftData

/// One day's log for a habit window. See docs/schema/habit.md.
@Model
public final class HabitEntry {
    public var id: UUID = UUID()
    public var date: Date = Date.now
    public var target: Int = 1
    public var amount: Int = 0
    public var completedAt: Date? = nil

    public var window: HabitTimeWindow?

    public init() {
    }
}
