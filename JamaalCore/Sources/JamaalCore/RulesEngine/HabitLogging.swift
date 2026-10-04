import Foundation
import SwiftData

public enum HabitLogAction: Sendable, Hashable {
    /// Binary: done / not done.
    case toggle
    /// Counted: one more / one fewer.
    case increment, decrement
    /// Avoid: a slip, taking one back, *Held today*, taking that back.
    case logSlip, undoSlip, heldToday, undoHeld
}

public enum HabitLogError: Error, Equatable, Sendable {
    /// The action isn't one this kind of habit has (timed minutes come from sessions).
    case wrongKind
}

/// Logging a habit from Today (docs/schema/habit.md, HabitEntry). The day's entry is created on the first log
/// with the window's target as a snapshot, so a later change of target never rewrites a past day; for the
/// kinds that complete, `completedAt` is set on reaching the target and cleared if the amount falls below it.
public enum HabitLogging {

    @MainActor
    public static func apply(
        _ action: HabitLogAction, to window: HabitTimeWindow, on day: CalendarDate, now: Date, context: ModelContext
    ) throws {
        let kind = window.habit?.habitKind ?? .unknown
        switch action {
        case .toggle where kind != .binary: throw HabitLogError.wrongKind
        case .increment where kind != .counted, .decrement where kind != .counted: throw HabitLogError.wrongKind
        case .logSlip where kind != .avoid, .undoSlip where kind != .avoid,
             .heldToday where kind != .avoid, .undoHeld where kind != .avoid: throw HabitLogError.wrongKind
        default: break
        }

        let entry = entry(for: window, on: day, context: context)
        switch action {
        case .toggle:
            entry.amount = entry.amount >= max(1, entry.target) ? 0 : max(1, entry.target)
            settle(entry, now: now)
        case .increment:
            entry.amount += 1
            settle(entry, now: now)
        case .decrement:
            entry.amount = max(0, entry.amount - 1)
            settle(entry, now: now)
        case .logSlip:
            entry.amount += 1
        case .undoSlip:
            entry.amount = max(0, entry.amount - 1)
        case .heldToday:
            entry.completedAt = now
        case .undoHeld:
            entry.completedAt = nil
        }
    }

    /// Past days can be put right for **14 days** (docs: a forgotten tick shouldn't be lost); older ones are read-only.
    /// Not before the habit existed, not in the future, and not on a paused day.
    public static func canCorrect(_ habit: Habit, day: CalendarDate, today: CalendarDate, boundary: DayBoundary) -> Bool {
        guard day <= today, today.days(until: day) > -14 else { return false }
        return day >= boundary.logicalDate(at: habit.createdAt) && !habit.isPaused(on: day)
    }

    /// The day's entry, created with a snapshot of the target if there isn't one. If two devices left two,
    /// the larger amount is the one that counts (and the one edited).
    @MainActor
    private static func entry(for window: HabitTimeWindow, on day: CalendarDate, context: ModelContext) -> HabitEntry {
        if let existing = (window.entries ?? []).filter({ CalendarDate(storedDate: $0.date) == day }).max(by: { $0.amount < $1.amount }) {
            return existing
        }
        let created = HabitEntry()
        created.date = day.storedDate
        created.target = window.target
        context.insert(created)
        created.window = window
        return created
    }

    /// Sets `completedAt` the first time the target is reached, keeps it while it stays reached, clears it below.
    private static func settle(_ entry: HabitEntry, now: Date) {
        if entry.amount >= max(1, entry.target) {
            if entry.completedAt == nil { entry.completedAt = now }
        } else {
            entry.completedAt = nil
        }
    }
}
