import Foundation
import SwiftData

/// The per-day record: capacity, plan and as-lived snapshot. See docs/architecture/rules-engine.md.
@Model
public final class DayPlan {
    public var id: UUID = UUID()
    public var date: Date = Date.now
    public var capacity: String = "medium"
    public var plannedTaskMinutes: Int = 0
    public var freeMinutes: Int = 0
    public var committedMinutes: Int = 0
    public var completedEffortMinutes: Int = 0
    public var loadScore: Int = 0
    public var wasOverloaded: Bool = false
    public var completionRate: Double = 0
    public var completionBasis: Int = 0
    public var planningCompletedAt: Date? = nil

    public init() {
    }

    /// Typed view of `capacity`; reads an unrecognised value as `.unknown` and never writes it back.
    public var capacityLevel: CapacityLevel {
        get { CapacityLevel(stored: capacity) }
        set { if let raw = newValue.storable { capacity = raw } }
    }
}
