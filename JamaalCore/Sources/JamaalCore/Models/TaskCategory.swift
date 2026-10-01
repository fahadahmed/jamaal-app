import Foundation
import SwiftData

/// An editable label for tasks. See docs/schema/task.md.
@Model
public final class TaskCategory {
    public var id: UUID = UUID()
    public var name: String = ""
    public var presetKey: String? = nil
    public var colorKey: String = "accent"
    public var sortOrder: Int = 0
    public var isArchived: Bool = false
    public var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.category) public var tasks: [TaskItem]?

    public init(name: String = "") {
        self.name = name
    }

    /// Typed view of `presetKey`; reads an unrecognised value as `.unknown` and never writes it back.
    public var preset: CategoryPreset? {
        get { presetKey.map { CategoryPreset(stored: $0) } }
        set { presetKey = newValue.flatMap(\.storable) }
    }

    /// Typed view of `colorKey`; reads an unrecognised value as `.unknown` and never writes it back.
    public var color: CategoryColor {
        get { CategoryColor(stored: colorKey) }
        set { if let raw = newValue.storable { colorKey = raw } }
    }
}
