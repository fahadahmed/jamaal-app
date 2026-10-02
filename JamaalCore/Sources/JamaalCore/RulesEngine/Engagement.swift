import Foundation
import SwiftData

/// "Engaged" days (docs/schema/habit.md, G-40): days on which the user did something in the app.
/// Opening it alone doesn't count. One definition serves avoid habits (a day is `complete` only
/// if the user engaged) and the rollover (a day with engagement gets a record).
public enum Engagement {

    /// Every logical day with any of: a task completed; a habit logged (`amount > 0`) or an
    /// avoid habit's *Held today* (or a past-day correction) set; an Anchor decided (anything
    /// but `pending`); a focus session; or the evening review of the day — a planning session for
    /// the next day, closed or skipped.
    @MainActor
    public static func engagedDays(in context: ModelContext, boundary: DayBoundary) throws -> Set<CalendarDate> {
        var days = Set<CalendarDate>()

        for task in try context.fetch(FetchDescriptor<TaskItem>()) where task.isCompleted {
            if let completedAt = task.completedAt { days.insert(boundary.logicalDate(at: completedAt)) }
        }
        for entry in try context.fetch(FetchDescriptor<HabitEntry>()) {
            let isAvoid = entry.window?.habit?.habitKind == .avoid
            if entry.amount > 0 || (isAvoid && entry.completedAt != nil) {
                days.insert(CalendarDate(storedDate: entry.date))
            }
        }
        for anchor in try context.fetch(FetchDescriptor<Anchor>()) where anchor.status != .pending {
            if let resolvedAt = anchor.resolvedAt { days.insert(boundary.logicalDate(at: resolvedAt)) }
        }
        for session in try context.fetch(FetchDescriptor<WorkSession>()) {
            days.insert(CalendarDate(storedDate: session.day))
        }
        for planning in try context.fetch(FetchDescriptor<NightPlanningSession>()) where planning.isComplete || planning.skippedAt != nil {
            days.insert(CalendarDate(storedDate: planning.forDate).addingDays(-1))
        }
        return days
    }
}
