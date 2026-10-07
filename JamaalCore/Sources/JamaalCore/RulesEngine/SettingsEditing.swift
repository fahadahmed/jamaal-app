import Foundation
import SwiftData

public enum SettingsError: Error, Equatable, Sendable {
    case normalDayOutOfRange
    /// A start or end that isn't a minute of the day, or a day shorter than two hours, or one that starts before the rollover.
    case workingDayInvalid
    case rolloverOutOfRange
    /// The new rollover (or the old one) hasn't passed yet today, so the logical date would flip.
    case rolloverNotChangeableNow
    case emptyName
    case nameTooLong
    case nameTaken
    case tooManyCategories
    case notFound
}

/// What the rollover control can do right now (docs/journeys/walkthroughs/07-capacity-and-day-settings.md, G-54).
public enum RolloverAvailability: Equatable, Sendable {
    /// Any value up to and including this minute of the day can be chosen: both it and the old one have passed.
    case upTo(Int)
    /// Not until this minute of the day: the current rollover hasn't passed yet today.
    case after(Int)
}

/// The numbers on "Capacity and day" (ST-02) and the rules that keep them consistent.
public enum DaySettings {
    public static let normalDayRange = 30...360
    public static let normalDayStep = 15
    public static let rolloverRange = 0...360
    public static let minimumWorkingDayMinutes = 120
    /// How many days of use the normal-day suggestion looks back, and how many it needs before it speaks.
    public static let suggestionWindowDays = 28
    public static let suggestionMinimumDays = 14
    public static let suggestionMinimumDifference = 30

    /// The normal day in 15-minute steps within 30 minutes to 6 hours.
    public static func setNormalDay(_ minutes: Int, on settings: UserSettings) throws {
        guard normalDayRange.contains(minutes), minutes % normalDayStep == 0 else { throw SettingsError.normalDayOutOfRange }
        settings.mediumDayMinutes = minutes
    }

    /// The working day: `rollover < start < end` within the day, with at least two hours between.
    public static func setWorkingDay(start: Int, end: Int, on settings: UserSettings) throws {
        guard (0..<1440).contains(start), (1..<1440).contains(end),
              settings.rolloverMinute < start, end - start >= minimumWorkingDayMinutes else { throw SettingsError.workingDayInvalid }
        settings.dayStartMinute = start
        settings.dayEndMinute = end
    }

    /// Which rollovers can be chosen at `nowMinute` (the minute of the day in the user's time zone).
    public static func rolloverAvailability(_ settings: UserSettings, nowMinute: Int) -> RolloverAvailability {
        nowMinute >= settings.rolloverMinute ? .upTo(min(nowMinute, rolloverRange.upperBound)) : .after(settings.rolloverMinute)
    }

    /// Changes when the new day starts. Safe by construction: only when the clock is past both the old and the new value,
    /// so both give the same logical date right now; the change applies from the next boundary. Stays before the working day.
    public static func setRollover(_ minute: Int, on settings: UserSettings, nowMinute: Int) throws {
        guard rolloverRange.contains(minute) else { throw SettingsError.rolloverOutOfRange }
        guard minute < settings.dayStartMinute else { throw SettingsError.workingDayInvalid }
        guard nowMinute >= max(minute, settings.rolloverMinute) else { throw SettingsError.rolloverNotChangeableNow }
        settings.rolloverMinute = minute
    }

    /// The quiet note when the planning prompt comes before the working day ends (G-57); `nil` otherwise.
    public static func planningBeforeDayEnd(_ settings: UserSettings) -> Int? {
        settings.planningMinute < settings.dayEndMinute ? settings.planningMinute : nil
    }

    // MARK: Learning the normal day (suggest only)

    /// "You usually do about 2h 40m": the median of the last 28 days' completed effort (days that had some), once 14 such
    /// days exist, rounded to 15 minutes and kept in range; offered only if it differs from now by 30 minutes or more,
    /// and not for 28 days after being declined, nor if this value was declined before.
    @MainActor
    public static func normalDaySuggestion(in context: ModelContext, settings: UserSettings, today: CalendarDate) throws -> Int? {
        let from = today.addingDays(-(suggestionWindowDays - 1)).storedDate
        let to = today.storedDate
        let plans = try context.fetch(FetchDescriptor<DayPlan>(predicate: #Predicate { $0.date >= from && $0.date <= to }))
        let days = plans.map(\.completedEffortMinutes).filter { $0 > 0 }.sorted()
        guard days.count >= suggestionMinimumDays else { return nil }
        let median = days.count % 2 == 1 ? Double(days[days.count / 2]) : Double(days[days.count / 2 - 1] + days[days.count / 2]) / 2
        let rounded = Int((median / Double(normalDayStep)).rounded()) * normalDayStep
        let value = min(normalDayRange.upperBound, max(normalDayRange.lowerBound, rounded))
        guard abs(value - settings.mediumDayMinutes) >= suggestionMinimumDifference else { return nil }

        let declined = try context.fetch(FetchDescriptor<NudgeLog>()).filter { $0.nudgeKind == .normalDaySuggestion && $0.dismissedAt != nil }
        let recently = declined.contains { ($0.dismissedAt ?? .distantPast) > today.storedDate.addingTimeInterval(-Double(suggestionWindowDays) * 86_400) }
        let same = declined.contains { $0.subjectKey == String(value) }
        return recently || same ? nil : value
    }

    /// The same suggestion for Night Planning's Load step: **at most once in Night Planning** per value. Showing it there is
    /// logged under its own key, so having seen it in Settings doesn't use up the one chance, and seeing it here doesn't
    /// hide it from Settings. A decline (anywhere) silences it as usual.
    @MainActor
    public static func normalDaySuggestionForPlanning(in context: ModelContext, settings: UserSettings, today: CalendarDate) throws -> Int? {
        guard let value = try normalDaySuggestion(in: context, settings: settings, today: today) else { return nil }
        let shown = try context.fetch(FetchDescriptor<NudgeLog>()).contains { $0.nudgeKind == .normalDaySuggestion && $0.subjectKey == planningKey(value) }
        return shown ? nil : value
    }

    /// Records that the suggestion was shown on the Load step (so it isn't shown there again).
    @MainActor
    public static func logShownInPlanning(_ minutes: Int, in context: ModelContext, now: Date) throws {
        let key = planningKey(minutes)
        guard try !context.fetch(FetchDescriptor<NudgeLog>()).contains(where: { $0.nudgeKind == .normalDaySuggestion && $0.subjectKey == key }) else { return }
        let log = NudgeLog()
        log.nudgeKind = .normalDaySuggestion
        log.subjectKey = key
        log.sentAt = now
        context.insert(log)
    }

    private static func planningKey(_ minutes: Int) -> String { "\(minutes)@planning" }

    /// Records that a suggestion was shown (once per value until it is declined).
    @MainActor
    public static func logShown(_ minutes: Int, in context: ModelContext, now: Date) throws {
        let key = String(minutes)
        let logs = try context.fetch(FetchDescriptor<NudgeLog>())
        guard !logs.contains(where: { $0.nudgeKind == .normalDaySuggestion && $0.subjectKey == key && $0.dismissedAt == nil }) else { return }
        let log = NudgeLog()
        log.nudgeKind = .normalDaySuggestion
        log.subjectKey = key
        log.sentAt = now
        context.insert(log)
    }

    /// *Not now*: marks the shown suggestion declined (writing one if it wasn't logged).
    @MainActor
    public static func decline(_ minutes: Int, in context: ModelContext, now: Date) throws {
        try logShown(minutes, in: context, now: now)
        let key = String(minutes)
        for log in try context.fetch(FetchDescriptor<NudgeLog>()) where log.nudgeKind == .normalDaySuggestion && log.subjectKey == key && log.dismissedAt == nil {
            log.dismissedAt = now
        }
    }
}

/// The category list (ST-04): a short list of personal labels, never a grouping axis.
public enum CategoryEditing {
    public static let nameLimit = 24
    public static let activeLimit = 8
    public static let colors: [CategoryColor] = [.accent, .blue, .ochre, .plum, .slate]

    private static func clean(_ name: String) throws -> String {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SettingsError.emptyName }
        guard text.count <= nameLimit else { throw SettingsError.nameTooLong }
        return text
    }

    /// Active categories in order.
    @MainActor
    public static func active(in context: ModelContext) throws -> [TaskCategory] {
        try all(in: context).filter { !$0.isArchived }
    }

    @MainActor
    public static func archived(in context: ModelContext) throws -> [TaskCategory] {
        try all(in: context).filter(\.isArchived)
    }

    @MainActor
    private static func all(in context: ModelContext) throws -> [TaskCategory] {
        try context.fetch(FetchDescriptor<TaskCategory>()).sorted { ($0.sortOrder, $0.createdAt, $0.id.uuidString) < ($1.sortOrder, $1.createdAt, $1.id.uuidString) }
    }

    /// Whether another label can be added: at most eight are active.
    @MainActor
    public static func canAdd(in context: ModelContext) throws -> Bool { try active(in: context).count < activeLimit }

    private static func isTaken(_ name: String, except: TaskCategory?, among list: [TaskCategory]) -> Bool {
        list.contains { $0 !== except && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    /// Adds a label at the end, in the next colour not yet used (or the first).
    @MainActor
    @discardableResult
    public static func add(name: String, color: CategoryColor? = nil, in context: ModelContext, now: Date) throws -> TaskCategory {
        let text = try clean(name)
        let list = try all(in: context)
        guard list.filter({ !$0.isArchived }).count < activeLimit else { throw SettingsError.tooManyCategories }
        guard !isTaken(text, except: nil, among: list) else { throw SettingsError.nameTaken }
        let used = Set(list.filter { !$0.isArchived }.map(\.color))
        let category = TaskCategory(name: text)
        category.color = color ?? colors.first { !used.contains($0) } ?? .accent
        category.sortOrder = (list.map(\.sortOrder).max() ?? -1) + 1
        category.createdAt = now
        context.insert(category)
        return category
    }

    /// Renames a label (a default keeps its `presetKey`).
    @MainActor
    public static func rename(_ category: TaskCategory, to name: String, in context: ModelContext) throws {
        let text = try clean(name)
        guard !isTaken(text, except: category, among: try all(in: context)) else { throw SettingsError.nameTaken }
        category.name = text
    }

    public static func setColor(_ color: CategoryColor, on category: TaskCategory) throws {
        guard colors.contains(color) else { throw SettingsError.notFound }
        category.color = color
    }

    /// Archives a label: its tasks keep it, it leaves the picker and the filter.
    public static func archive(_ category: TaskCategory) { category.isArchived = true }

    /// Brings an archived label back, at the end of the list, if there is room.
    @MainActor
    public static func restore(_ category: TaskCategory, in context: ModelContext) throws {
        guard category.isArchived else { return }
        let list = try all(in: context)
        guard list.filter({ !$0.isArchived }).count < activeLimit else { throw SettingsError.tooManyCategories }
        category.isArchived = false
        category.sortOrder = (list.map(\.sortOrder).max() ?? -1) + 1
    }

    /// Moves a label within the active list and renumbers it.
    @MainActor
    public static func move(_ category: TaskCategory, to index: Int, in context: ModelContext) throws {
        var list = try active(in: context)
        guard let from = list.firstIndex(where: { $0 === category }) else { throw SettingsError.notFound }
        list.remove(at: from)
        list.insert(category, at: max(0, min(index, list.count)))
        for (position, item) in list.enumerated() { item.sortOrder = position }
    }
}
