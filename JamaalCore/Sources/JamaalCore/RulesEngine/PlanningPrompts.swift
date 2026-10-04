import Foundation
import SwiftData

/// The morning card (docs/journeys/today-list.md, TD-07): one quiet card when no plan was confirmed for today
/// (Night Planning was skipped or missed). It is logged once a day (`NudgeLog`, `subjectKey` = the date), stays
/// until it is dismissed or acted on, and goes once a plan for today is confirmed or the working day is over.
public enum MorningCard {

    @MainActor
    public static func isDue(now: Date, boundary: DayBoundary, context: ModelContext) throws -> Bool {
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first ?? UserSettings()
        let today = boundary.logicalDate(at: now)
        guard now < boundary.instant(of: today, atMinute: settings.dayEndMinute) else { return false }
        let planned = try context.fetch(FetchDescriptor<NightPlanningSession>())
            .contains { CalendarDate(storedDate: $0.forDate) == today && $0.isComplete }
        if planned { return false }
        return try log(on: today, in: context)?.dismissedAt == nil
    }

    /// Records that the card was shown today (once).
    @MainActor
    public static func markShown(now: Date, boundary: DayBoundary, context: ModelContext) throws {
        _ = try ensureLog(on: boundary.logicalDate(at: now), now: now, in: context)
    }

    /// Puts the card away for today: *Not now*, or *Pick for today*.
    @MainActor
    public static func dismiss(now: Date, boundary: DayBoundary, context: ModelContext) throws {
        try ensureLog(on: boundary.logicalDate(at: now), now: now, in: context).dismissedAt = now
    }

    @MainActor
    private static func log(on day: CalendarDate, in context: ModelContext) throws -> NudgeLog? {
        try context.fetch(FetchDescriptor<NudgeLog>())
            .filter { $0.nudgeKind == .morningPlanCard && $0.subjectKey == day.isoString }
            .min { ($0.sentAt, $0.id.uuidString) < ($1.sentAt, $1.id.uuidString) }
    }

    @MainActor
    private static func ensureLog(on day: CalendarDate, now: Date, in context: ModelContext) throws -> NudgeLog {
        if let existing = try log(on: day, in: context) { return existing }
        let log = NudgeLog()
        log.nudgeKind = .morningPlanCard
        log.subjectKey = day.isoString
        log.sentAt = now
        context.insert(log)
        return log
    }
}

extension NightPlanning {

    /// Whether Today shows the quiet **Plan tomorrow** row: from the planning time until the next day starts, if
    /// that night's plan is neither confirmed nor skipped. (An unfinished one still gets the row.)
    @MainActor
    public static func eveningPromptDue(now: Date, boundary: DayBoundary, context: ModelContext) throws -> Bool {
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first ?? UserSettings()
        let today = boundary.logicalDate(at: now)
        let beforeTheDayStarts = now < boundary.instant(of: today, atMinute: settings.dayStartMinute)
        let afterThePlanningTime = now >= boundary.instant(of: today, atMinute: settings.planningMinute)
        guard beforeTheDayStarts || afterThePlanningTime else { return false }

        let target = boundary.planningTarget(at: now, dayStartMinute: settings.dayStartMinute).forDate
        let session = try context.fetch(FetchDescriptor<NightPlanningSession>())
            .first { CalendarDate(storedDate: $0.forDate) == target }
        return !(session?.isComplete == true || session?.skippedAt != nil)
    }
}
