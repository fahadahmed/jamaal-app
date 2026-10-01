import Foundation
import SwiftData
@testable import JamaalCore

/// Shared builders for the habit and engagement tests. Times are UTC with a midnight rollover.
@MainActor
struct HabitWorld {
    let context: ModelContext
    let boundary = DayBoundary(rolloverMinute: 0, timeZone: TimeZone(identifier: "UTC")!)

    init() throws { context = ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }

    func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }   // 1 Oct 2026 is a Thursday
    func instant(_ day: Int, _ hour: Int = 12) -> Date { boundary.instant(of: d(day), atMinute: hour * 60) }

    /// A habit created at the start of `createdOn` with one all-day window.
    func habit(
        _ title: String = "Habit", kind: HabitKind = .binary, target: Int = 1,
        days: String = "1,2,3,4,5,6,7", perWeek: Int = 0, createdOn: Int = 1, effort: Int? = nil
    ) -> (habit: Habit, window: HabitTimeWindow) {
        let habit = Habit(title: title)
        habit.habitKind = kind
        habit.scheduledDays = days
        habit.targetPerWeek = perWeek
        habit.createdAt = instant(createdOn, 0)
        context.insert(habit)
        let window = HabitTimeWindow()
        window.target = target
        window.effortMinutes = effort
        context.insert(window)
        window.habit = habit
        return (habit, window)
    }

    @discardableResult
    func entry(_ window: HabitTimeWindow, day: Int, amount: Int, target: Int? = nil, completed: Bool = false) -> HabitEntry {
        let e = HabitEntry()
        e.date = d(day).storedDate
        e.amount = amount
        e.target = target ?? window.target
        if completed { e.completedAt = instant(day) }
        context.insert(e)
        e.window = window
        return e
    }

    func ctx(today: Int, engaged: Set<Int> = [], firstWeekday: Int = 1) -> HabitContext {
        HabitContext(boundary: boundary, today: d(today), firstWeekday: firstWeekday, engagedDays: Set(engaged.map(d)))
    }
}
