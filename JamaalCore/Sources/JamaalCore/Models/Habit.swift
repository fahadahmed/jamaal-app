import Foundation
import SwiftData

/// Something you cultivate. See docs/schema/habit.md.
@Model
public final class Habit {
    public var id: UUID = UUID()
    public var title: String = ""
    public var notes: String? = nil
    public var presetKey: String? = nil
    public var kind: String = "binary"
    public var frequency: String = "daily"
    public var scheduledDays: String = "1,2,3,4,5,6,7"
    public var targetPerWeek: Int = 0
    public var pausesData: String = "[]"
    public var isArchived: Bool = false
    public var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \HabitTimeWindow.habit) public var windows: [HabitTimeWindow]?
    public var group: HabitGroup?

    public init(title: String = "") {
        self.title = title
    }

    /// Typed view of `kind`; reads an unrecognised value as `.unknown` and never writes it back.
    public var habitKind: HabitKind {
        get { HabitKind(stored: kind) }
        set { if let raw = newValue.storable { kind = raw } }
    }

    /// Typed view of `frequency`; reads an unrecognised value as `.unknown` and never writes it back.
    public var frequencyKind: HabitFrequency {
        get { HabitFrequency(stored: frequency) }
        set { if let raw = newValue.storable { frequency = raw } }
    }

    /// Typed view of `presetKey`; reads an unrecognised value as `.unknown` and never writes it back.
    public var preset: HabitPreset? {
        get { presetKey.map { HabitPreset(stored: $0) } }
        set { presetKey = newValue.flatMap(\.storable) }
    }
}
