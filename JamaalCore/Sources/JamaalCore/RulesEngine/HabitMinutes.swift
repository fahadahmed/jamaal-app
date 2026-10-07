import Foundation
import SwiftData

public enum HabitMinutesError: Error, Equatable, Sendable {
    /// Minutes are for timed habits.
    case notATimedHabit
    case minutesOutOfRange
    /// Older than 14 days, before the habit existed, in the future, or on a paused day.
    case dayNotOpenForCorrection
}

/// Minutes added by hand (HB-09, docs/schema/habit.md): a finished `manual` session on the habit's window, so the day's total
/// is still the sum of its sessions and two devices converge. Adding the day is allowed for the same 14 days a forgotten
/// tick can be put right; one entry can be taken back out. This is living the day, so it is never locked.
public enum HabitMinutes {
    public static let step = 5
    public static let range = 1...720
    public static let defaultMinutes = 10

    /// Adds `minutes` to the window's day. Nothing is written if it is refused.
    @MainActor
    @discardableResult
    public static func add(
        _ minutes: Int, to window: HabitTimeWindow, on day: CalendarDate, now: Date, boundary: DayBoundary, context: ModelContext
    ) throws -> WorkSession {
        guard let habit = window.habit, habit.habitKind == .timed else { throw HabitMinutesError.notATimedHabit }
        guard range.contains(minutes) else { throw HabitMinutesError.minutesOutOfRange }
        guard HabitLogging.canCorrect(habit, day: day, today: boundary.logicalDate(at: now), boundary: boundary) else {
            throw HabitMinutesError.dayNotOpenForCorrection
        }
        return FocusSessions.addMinutes(minutes, to: window, on: day, now: now, context: context)
    }

    /// The minutes added by hand on that day, newest first, so a mistaken one can be taken back.
    public static func manualSessions(of window: HabitTimeWindow, on day: CalendarDate) -> [WorkSession] {
        (window.sessions ?? [])
            .filter { $0.outcomeKind == .manual && CalendarDate(storedDate: $0.day) == day }
            .sorted { ($0.startedAt, $0.id.uuidString) > ($1.startedAt, $1.id.uuidString) }
    }

    /// Takes an entry made by hand back out; the day's total follows. Only a manual session can be removed this way.
    @MainActor
    @discardableResult
    public static func remove(_ session: WorkSession, now: Date, context: ModelContext) -> Bool {
        guard session.outcomeKind == .manual, let window = session.habitWindow else { return false }
        let day = CalendarDate(storedDate: session.day)
        window.sessions?.removeAll { $0.id == session.id }                          // the window's list is stale until a save
        context.delete(session)
        HabitSessions.recompute(window, on: day, now: now, context: context)
        return true
    }

    /// The day's minutes so far against the target, as the entry holds them.
    public static func progress(of window: HabitTimeWindow, on day: CalendarDate) -> (done: Int, target: Int) {
        let entry = (window.entries ?? []).filter { CalendarDate(storedDate: $0.date) == day }.max { $0.amount < $1.amount }
        return (entry?.amount ?? 0, entry?.target ?? window.target)
    }
}
