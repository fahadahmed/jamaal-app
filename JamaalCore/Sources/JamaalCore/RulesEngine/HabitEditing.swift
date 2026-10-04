import Foundation
import SwiftData

public enum HabitEditError: Error, Equatable, Sendable {
    case emptyTitle
    /// A count or a number of minutes below one (an avoid habit's allowance may be zero).
    case targetTooSmall
    /// Some days, or "N times a week", have to be chosen.
    case noDays
    case badWeeklyTarget
    case noWindow
    case tooManyWindows
    /// With more than one time of day, each has a name ("Morning", "Evening").
    case windowNeedsALabel
    case windowEndsBeforeItStarts
    /// A time of day that has entries can't be removed: its history would go with it.
    case windowHasHistory
}

/// One time of day in a habit form. `id` is set when it is an existing window being edited.
public struct HabitWindowDraft: Equatable {
    public var id: UUID?
    public var label: String
    public var startMinute: Int
    public var endMinute: Int
    public var target: Int
    public var effortMinutes: Int?
    public var reminderMinute: Int?

    public init(
        id: UUID? = nil, label: String = "", startMinute: Int = 0, endMinute: Int = 1439, target: Int,
        effortMinutes: Int? = nil, reminderMinute: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.target = target
        self.effortMinutes = effortMinutes
        self.reminderMinute = reminderMinute
    }
}

/// What the add / edit habit form collects (HB-03/04). The kind is chosen first and is fixed afterwards, because
/// history is read by it.
public struct HabitDraft {
    public var title = ""
    public var kind: HabitKind
    public var windows: [HabitWindowDraft]
    /// ISO weekdays (Monday = 1). Ignored while `perWeek` is set.
    public var weekdays: Set<Int> = Set(1...7)
    /// "N times a week" (1–7, any days), or 0 for fixed days.
    public var perWeek = 0
    public var group: HabitGroup?
    public var notes: String?
    public var presetKey: String?

    public init(kind: HabitKind) {
        self.kind = kind
        let target: Int
        switch kind {
        case .counted: target = 3
        case .timed: target = 15
        case .binary, .avoid, .unknown: target = 1
        }
        windows = [HabitWindowDraft(target: target)]
    }

    /// A built-in (docs/schema/habit.md, Presets): one all-day window, everything editable afterwards.
    public static func preset(_ preset: HabitPreset) -> HabitDraft {
        var draft: HabitDraft
        switch preset {
        case .quran:
            draft = HabitDraft(kind: .timed); draft.title = "Qur'an reading"
            draft.windows[0].target = 15; draft.windows[0].effortMinutes = 15
        case .dhikr:
            draft = HabitDraft(kind: .counted); draft.title = "Dhikr"
            draft.windows[0].target = 33
        case .exercise:
            draft = HabitDraft(kind: .timed); draft.title = "Exercise"
            draft.windows[0].target = 30; draft.windows[0].effortMinutes = 30; draft.perWeek = 3
        case .running:
            draft = HabitDraft(kind: .timed); draft.title = "Running"
            draft.windows[0].target = 30; draft.windows[0].effortMinutes = 30; draft.perWeek = 3
        case .unknown:
            draft = HabitDraft(kind: .binary)
        }
        draft.presetKey = preset.storable
        return draft
    }

    /// The form for an existing habit.
    public init(editing habit: Habit) {
        self.init(kind: habit.habitKind)
        title = habit.title
        weekdays = habit.scheduledWeekdays
        perWeek = habit.targetPerWeek
        group = habit.group
        notes = habit.notes
        presetKey = habit.presetKey
        windows = (habit.windows ?? [])
            .sorted { ($0.startMinute, $0.label, $0.id.uuidString) < ($1.startMinute, $1.label, $1.id.uuidString) }
            .map {
                HabitWindowDraft(
                    id: $0.id, label: $0.label, startMinute: $0.startMinute, endMinute: $0.endMinute, target: $0.target,
                    effortMinutes: $0.effortMinutes, reminderMinute: $0.reminderMinute)
            }
    }
}

public enum HabitEditing {
    public static let maxWindows = 4

    /// Validates the draft and inserts the habit with its times of day. Nothing is written when it is refused.
    @MainActor
    @discardableResult
    public static func create(_ draft: HabitDraft, in context: ModelContext, now: Date) throws -> Habit {
        try validate(draft)
        let habit = Habit(title: trimmed(draft.title))
        habit.habitKind = draft.kind
        habit.createdAt = now
        context.insert(habit)
        apply(draft, to: habit)
        for window in draft.windows {
            let new = HabitTimeWindow()
            context.insert(new)
            new.habit = habit
            copy(window, into: new)
        }
        return habit
    }

    /// Applies the form to an existing habit. **The kind never changes.** A time of day can be added, and one with
    /// no entries removed, but one with history can't be (its entries would go with it). A changed target affects the
    /// future only: every entry kept the target it was made under. Nothing is written when it is refused.
    @MainActor
    public static func update(_ habit: Habit, with draft: HabitDraft, in context: ModelContext) throws {
        var draft = draft
        draft.kind = habit.habitKind
        try validate(draft)

        let kept = Set(draft.windows.compactMap(\.id))
        let removed = (habit.windows ?? []).filter { !kept.contains($0.id) }
        if removed.contains(where: { !($0.entries ?? []).isEmpty }) { throw HabitEditError.windowHasHistory }

        habit.title = trimmed(draft.title)
        apply(draft, to: habit)
        let removedIDs = Set(removed.map(\.id))
        habit.windows?.removeAll { removedIDs.contains($0.id) }          // the relationship, now, not at the next save
        for window in removed { context.delete(window) }
        for window in draft.windows {
            if let id = window.id, let existing = habit.windows?.first(where: { $0.id == id }) {
                copy(window, into: existing)
            } else {
                let new = HabitTimeWindow()
                context.insert(new)
                new.habit = habit
                copy(window, into: new)
            }
        }
    }

    /// A new group with the next sort order.
    @MainActor
    @discardableResult
    public static func createGroup(named name: String, in context: ModelContext) throws -> HabitGroup {
        let title = trimmed(name)
        guard !title.isEmpty else { throw HabitEditError.emptyTitle }
        let next = (try context.fetch(FetchDescriptor<HabitGroup>()).map(\.sortOrder).max() ?? -1) + 1
        let group = HabitGroup()
        group.title = title
        group.sortOrder = next
        context.insert(group)
        return group
    }

    // MARK: Helpers

    private static func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func validate(_ draft: HabitDraft) throws {
        guard !trimmed(draft.title).isEmpty else { throw HabitEditError.emptyTitle }
        guard !draft.windows.isEmpty else { throw HabitEditError.noWindow }
        guard draft.windows.count <= maxWindows else { throw HabitEditError.tooManyWindows }
        let smallest = draft.kind == .avoid ? 0 : 1
        for window in draft.windows {
            if draft.windows.count > 1 && trimmed(window.label).isEmpty { throw HabitEditError.windowNeedsALabel }
            guard window.endMinute > window.startMinute else { throw HabitEditError.windowEndsBeforeItStarts }
            guard window.target >= smallest else { throw HabitEditError.targetTooSmall }
        }
        guard (0...7).contains(draft.perWeek) else { throw HabitEditError.badWeeklyTarget }
        if draft.perWeek == 0 && draft.weekdays.filter({ (1...7).contains($0) }).isEmpty { throw HabitEditError.noDays }
    }

    @MainActor
    private static func apply(_ draft: HabitDraft, to habit: Habit) {
        let days = draft.weekdays.filter { (1...7).contains($0) }
        if draft.perWeek > 0 {
            habit.frequencyKind = .custom
            habit.targetPerWeek = draft.perWeek
            habit.scheduledDays = "1,2,3,4,5,6,7"
        } else {
            habit.frequencyKind = days.count == 7 ? .daily : (days == [1, 2, 3, 4, 5] ? .weekdays : .custom)
            habit.targetPerWeek = 0
            habit.scheduledDays = days.sorted().map(String.init).joined(separator: ",")
        }
        habit.group = draft.group
        let note = draft.notes.map(trimmed) ?? ""
        habit.notes = note.isEmpty ? nil : note
        habit.presetKey = draft.presetKey
    }

    private static func copy(_ window: HabitWindowDraft, into target: HabitTimeWindow) {
        target.label = trimmed(window.label)
        target.startMinute = window.startMinute
        target.endMinute = window.endMinute
        target.target = window.target
        target.effortMinutes = window.effortMinutes
        target.reminderMinute = window.reminderMinute
    }
}
