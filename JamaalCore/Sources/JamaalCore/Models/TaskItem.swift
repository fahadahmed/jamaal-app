import Foundation
import SwiftData

/// A thing you do (the product calls it a Task). Named `TaskItem` so it never shadows `Swift.Task`.
/// See docs/schema/task.md.
@Model
public final class TaskItem {
    public var id: UUID = UUID()
    public var title: String = ""
    public var notes: String? = nil
    public var dueDate: Date? = nil
    public var effortMinutes: Int? = nil
    public var importance: String = "low"
    public var isCompleted: Bool = false
    public var completedAt: Date? = nil
    public var droppedAt: Date? = nil
    public var deferralCount: Int = 0
    public var repeatKind: String = "none"
    public var repeatWeekdays: String = ""
    public var seriesID: UUID? = nil
    public var createdAt: Date = Date.now

    public var category: TaskCategory?
    @Relationship(deleteRule: .cascade, inverse: \DeferralRecord.task) public var deferrals: [DeferralRecord]?
    @Relationship(deleteRule: .cascade, inverse: \WorkSession.task) public var sessions: [WorkSession]?

    public init(title: String = "", dueDate: Date? = nil, effortMinutes: Int? = nil) {
        self.title = title
        self.dueDate = dueDate
        self.effortMinutes = effortMinutes
    }

    /// Typed view of `importance`; reads an unrecognised value as `.unknown` and never writes it back.
    public var importanceLevel: Importance {
        get { Importance(stored: importance) }
        set { if let raw = newValue.storable { importance = raw } }
    }

    /// Typed view of `repeatKind`; reads an unrecognised value as `.unknown` and never writes it back.
    public var repeatMode: RepeatKind {
        get { RepeatKind(stored: repeatKind) }
        set { if let raw = newValue.storable { repeatKind = raw } }
    }
}
