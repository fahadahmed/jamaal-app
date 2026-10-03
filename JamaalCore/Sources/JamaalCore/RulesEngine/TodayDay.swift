import Foundation
import SwiftData

/// What Today's header and task list read for one logical day.
public struct TodayOverview {
    public var today: CalendarDate
    public var level: CapacityLevel
    public var budgetMinutes: Int
    /// Task minutes against the budget: the tasks Today shows plus those already done today.
    public var plannedMinutes: Int
    public var loadScore: Int
    public var state: LoadState
    /// Counted tasks with no estimate (they add nothing to `plannedMinutes`).
    public var missingEstimates: Int
    public var shown: [TaskItem]
    public var alsoToday: [TaskItem]
    public var completedToday: [TaskItem]
}

/// Module 7 as Today uses it: the level for the day, the meter's numbers, and moving the slider.
public enum TodayDay {

    @MainActor
    public static func overview(in context: ModelContext, now: Date, timeZone: TimeZone = .current) throws -> TodayOverview {
        let settings = try settingsRow(in: context)
        let boundary = DayBoundary(rolloverMinute: settings.rolloverMinute, timeZone: timeZone)
        let today = boundary.logicalDate(at: now)
        let level = try level(for: today, settings: settings, in: context)

        let list = TodayTasks.list(try context.fetch(FetchDescriptor<TaskItem>()), today: today, level: level, boundary: boundary)
        let counted = list.shown + list.completedToday
        let planned = counted.reduce(0) { $0 + ($1.effortMinutes ?? 0) }
        let budget = CapacityLoad.budgetMinutes(for: level, mediumDayMinutes: settings.mediumDayMinutes)
        let score = CapacityLoad.loadScore(plannedMinutes: planned, budgetMinutes: budget)

        return TodayOverview(
            today: today, level: level, budgetMinutes: budget, plannedMinutes: planned, loadScore: score,
            state: LoadState(score: score), missingEstimates: counted.filter { $0.effortMinutes == nil }.count,
            shown: list.shown, alsoToday: list.alsoToday, completedToday: list.completedToday
        )
    }

    /// The day boundary on the user's rollover time, for actions that need to attribute a moment to a day.
    @MainActor
    public static func boundary(in context: ModelContext, timeZone: TimeZone = .current) -> DayBoundary {
        let rollover = (try? settingsRow(in: context).rolloverMinute) ?? 0
        return DayBoundary(rolloverMinute: rollover, timeZone: timeZone)
    }

    /// Moves the slider: upserts today's `DayPlan.capacity`.
    @MainActor
    public static func setLevel(_ level: CapacityLevel, in context: ModelContext, now: Date, timeZone: TimeZone = .current) throws {
        let settings = try settingsRow(in: context)
        let today = DayBoundary(rolloverMinute: settings.rolloverMinute, timeZone: timeZone).logicalDate(at: now)
        let plan = try dayPlan(for: today, in: context) ?? {
            let new = DayPlan()
            new.date = today.storedDate
            context.insert(new)
            return new
        }()
        plan.capacityLevel = level
    }

    @MainActor
    private static func level(for day: CalendarDate, settings: UserSettings, in context: ModelContext) throws -> CapacityLevel {
        if let plan = try dayPlan(for: day, in: context), !plan.capacityLevel.isUnknown { return plan.capacityLevel }
        return settings.defaultLevel(forISOWeekday: day.isoWeekday)
    }

    @MainActor
    private static func dayPlan(for day: CalendarDate, in context: ModelContext) throws -> DayPlan? {
        try context.fetch(FetchDescriptor<DayPlan>())
            .filter { CalendarDate(storedDate: $0.date) == day }
            .min { $0.id.uuidString < $1.id.uuidString }
    }

    @MainActor
    private static func settingsRow(in context: ModelContext) throws -> UserSettings {
        try context.fetch(FetchDescriptor<UserSettings>())
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) } ?? UserSettings()
    }
}
