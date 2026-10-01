import Foundation
import SwiftData

/// A focus session on a task or a habit window. See docs/schema/task.md, "Focus sessions".
@Model
public final class WorkSession {
    public var id: UUID = UUID()
    public var startedAt: Date = Date.now
    public var day: Date = Date.now
    public var endedAt: Date? = nil
    public var pausedSeconds: Int = 0
    public var pausedAt: Date? = nil
    public var estimateMinutes: Int? = nil
    public var outcome: String = "running"
    public var actualSeconds: Int = 0

    public var task: TaskItem?
    public var habitWindow: HabitTimeWindow?

    public init() {
    }

    /// Typed view of `outcome`; reads an unrecognised value as `.unknown` and never writes it back.
    public var outcomeKind: SessionOutcome {
        get { SessionOutcome(stored: outcome) }
        set { if let raw = newValue.storable { outcome = raw } }
    }
}
