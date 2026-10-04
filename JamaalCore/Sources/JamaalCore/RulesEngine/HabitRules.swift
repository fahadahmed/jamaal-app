import Foundation

/// What the habit rules need to know about "now" and the user.
public struct HabitContext: Sendable {
    public var boundary: DayBoundary
    /// The current logical date.
    public var today: CalendarDate
    /// The first day of the week, as an ISO weekday (Monday = 1 … Sunday = 7).
    public var firstWeekday: Int
    /// Days on which the user did something in the app (see `Engagement`); only avoid habits read it.
    public var engagedDays: Set<CalendarDate>

    public init(boundary: DayBoundary, today: CalendarDate, firstWeekday: Int = 1, engagedDays: Set<CalendarDate> = []) {
        self.boundary = boundary
        self.today = today
        self.firstWeekday = firstWeekday
        self.engagedDays = engagedDays
    }
}

/// A day's cell in a habit's grid (docs/schema/habit.md, "Density states").
public enum DensityState: Sendable, Hashable {
    /// Nothing to show: not scheduled, paused, before the habit existed, in the future, or still open.
    case empty
    case missed
    case complete
    /// 1–49% of the target.
    case partialLow
    /// 50–99% of the target.
    case partialHigh
}

public struct DensityCell: Equatable, Sendable {
    public var day: CalendarDate
    public var state: DensityState
}

/// The signal behind the plain-language read; a separate layer phrases it.
public struct DensityRead: Equatable, Sendable {
    public var windowDays: Int
    public var completed = 0
    public var partial = 0
    public var missed = 0

    public init(windowDays: Int) { self.windowDays = windowDays }

    /// Resolved days: completed + partial + missed. Paused, unscheduled and still-open days are left out.
    public var due: Int { completed + partial + missed }
    /// More than half the resolved days missed, over at least a week of them: "try a lighter cadence?".
    public var suggestsLighterCadence: Bool { due >= HabitDensity.minimumDaysForSuggestion && missed * 2 > due }
}

public struct WeeklyProgress: Equatable, Sendable {
    /// Days this week on which every window met its own target.
    public var done: Int
    public var target: Int
    public var isMet: Bool { done >= target }

    public init(done: Int, target: Int) {
        self.done = done
        self.target = target
    }
}


/// Entries for a window, whichever way they are reached.
enum HabitWindowAccess {
    /// The entry for `day`; if two devices left two, the larger amount.
    static func entry(of window: HabitTimeWindow, on day: CalendarDate) -> HabitEntry? {
        (window.entries ?? [])
            .filter { CalendarDate(storedDate: $0.date) == day }
            .max { $0.amount < $1.amount }
    }

    static func createdDay(_ habit: Habit, _ context: HabitContext) -> CalendarDate {
        context.boundary.logicalDate(at: habit.createdAt)
    }
}

/// Which days a habit applies to.
public enum HabitSchedule {

    /// Whether `day` is one of the habit's days: its scheduled weekdays, or every day for a
    /// "N times a week" habit (which shows until the week's target is met).
    public static func isScheduled(_ habit: Habit, on day: CalendarDate) -> Bool {
        habit.targetPerWeek > 0 || habit.scheduledWeekdays.contains(day.isoWeekday)
    }

    /// Whether the habit is live on `day`: not archived, already created, and not paused.
    public static func isActive(_ habit: Habit, on day: CalendarDate, context: HabitContext) -> Bool {
        !habit.isArchived && day >= HabitWindowAccess.createdDay(habit, context) && !habit.isPaused(on: day)
    }

    /// Progress toward a "N times a week" habit for the week containing `day`, or `nil` for a
    /// fixed-day habit. A day counts when every window met its own target that day.
    public static func weeklyProgress(of habit: Habit, on day: CalendarDate, context: HabitContext) -> WeeklyProgress? {
        guard habit.targetPerWeek > 0 else { return nil }
        let offset = (day.isoWeekday - context.firstWeekday + 7) % 7
        let weekStart = day.addingDays(-offset)
        let windows = habit.windows ?? []
        guard !windows.isEmpty else { return WeeklyProgress(done: 0, target: habit.targetPerWeek) }
        let done = (0..<7).map { weekStart.addingDays($0) }.filter { date in
            windows.allSatisfy { HabitDensity.state(of: $0, on: date, context: context) == .complete }
        }.count
        return WeeklyProgress(done: done, target: habit.targetPerWeek)
    }
}

/// Density, never streaks: how much was done each due day.
public enum HabitDensity {
    static let minimumDaysForSuggestion = 7

    /// The cell for one window on one day.
    ///
    /// Binary, counted and timed: complete at the target (more doesn't over-fill), partial in two
    /// steps, `missed` for a due past day with nothing done, `empty` while the day is still open.
    /// A "N times a week" habit is never `missed`. Avoid: `missed` once slips pass the allowance,
    /// `complete` only if slips are within it **and** the user engaged that day (or tapped *Held
    /// today*), otherwise `empty` — silence is never success — and today stays unresolved.
    public static func state(of window: HabitTimeWindow, on day: CalendarDate, context: HabitContext) -> DensityState {
        guard let habit = window.habit, day <= context.today,
              day >= HabitWindowAccess.createdDay(habit, context), !habit.isPaused(on: day) else { return .empty }

        let weekly = habit.targetPerWeek > 0
        let isDueDay = weekly || HabitSchedule.isScheduled(habit, on: day)
        let entry = HabitWindowAccess.entry(of: window, on: day)
        let amount = entry?.amount ?? 0

        if habit.habitKind == .avoid {
            guard day < context.today else { return .empty }
            let allowance = max(0, entry?.target ?? window.target)
            if amount > allowance { return .missed }
            let engaged = entry?.completedAt != nil || context.engagedDays.contains(day)
            return isDueDay && engaged ? .complete : .empty
        }

        let target = max(1, entry?.target ?? window.target)
        if amount >= target { return .complete }
        if amount > 0 { return Double(amount) / Double(target) < 0.5 ? .partialLow : .partialHigh }
        if day == context.today || weekly || !isDueDay { return .empty }
        return .missed
    }

    /// The last `days` cells for a window, oldest first, ending today.
    public static func grid(of window: HabitTimeWindow, days: Int, context: HabitContext) -> [DensityCell] {
        (0..<max(0, days)).reversed().map { offset in
            let day = context.today.addingDays(-offset)
            return DensityCell(day: day, state: state(of: window, on: day, context: context))
        }
    }

    /// Counts for the read over the last `windowDays` days, across every window. Today is left
    /// out until it is finished, because an open day isn't resolved.
    public static func read(of habit: Habit, windowDays: Int, context: HabitContext) -> DensityRead {
        var read = DensityRead(windowDays: windowDays)
        for window in habit.windows ?? [] {
            for cell in grid(of: window, days: windowDays, context: context) {
                if cell.day == context.today, cell.state != .complete { continue }
                switch cell.state {
                case .complete: read.completed += 1
                case .partialLow, .partialHigh: read.partial += 1
                case .missed: read.missed += 1
                case .empty: break
                }
            }
        }
        return read
    }
}

/// A habit window Today shows.
public struct DueWindow {
    public var habit: Habit
    public var window: HabitTimeWindow
    /// Already met today (an avoid habit: *Held today* tapped). Shown, as done.
    public var isDone: Bool
    /// Amount logged today (count, minutes or slips).
    public var amountToday: Int
}

/// Today's habits.
public enum HabitToday {

    /// The windows to show today: live habits that are scheduled today, plus "N times a week"
    /// habits every day of the week — offered until the week's target is met, then shown as done.
    public static func dueWindows(of habits: [Habit], context: HabitContext) -> [DueWindow] {
        let today = context.today
        var result: [DueWindow] = []
        for habit in habits where HabitSchedule.isActive(habit, on: today, context: context) {
            let weekMet = HabitSchedule.weeklyProgress(of: habit, on: today, context: context)?.isMet ?? false
            guard HabitSchedule.isScheduled(habit, on: today) else { continue }
            for window in habit.windows ?? [] {
                let entry = HabitWindowAccess.entry(of: window, on: today)
                let amount = entry?.amount ?? 0
                let met: Bool
                if habit.habitKind == .avoid {
                    met = entry?.completedAt != nil
                } else {
                    met = amount >= max(1, entry?.target ?? window.target)
                }
                result.append(DueWindow(habit: habit, window: window, isDone: met || weekMet, amountToday: amount))
            }
        }
        return result
    }

    /// Minutes the unfinished windows still take from the day: what free time subtracts. A timed
    /// window counts its effort (default: the target) less what is already logged; any other
    /// kind counts its effort until it is done; a window with no duration counts nothing.
    public static func remainingMinutes(_ due: [DueWindow]) -> Int {
        due.filter { !$0.isDone }.reduce(0) { total, item in
            let effort = item.window.effortMinutes
            if item.habit.habitKind == .timed {
                return total + max(0, (effort ?? item.window.target) - item.amountToday)
            }
            return total + (effort ?? 0)
        }
    }
}
