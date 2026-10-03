import Foundation
import SwiftData

/// What wellbeing can notice. The declaration order is the priority when more than one shows.
public enum PatternKind: String, Sendable, CaseIterable {
    case heavyRun, completionCollapse, weekendOverplan, habitNeglect
}

/// A pattern that is active now, with what the card needs to act on it.
public struct WellbeingPattern {
    public var kind: PatternKind
    /// Identifies it for the once-a-day and cooldown rules: the pattern, plus the habit or weekday.
    public var subjectKey: String
    public var habit: Habit?
    /// The weekend day to lighten (6 Saturday, 7 Sunday).
    public var weekday: Int?

    public init(kind: PatternKind, subjectKey: String, habit: Habit? = nil, weekday: Int? = nil) {
        self.kind = kind
        self.subjectKey = subjectKey
        self.habit = habit
        self.weekday = weekday
    }
}

/// The one inline card: a pattern and, behind it, one change.
public struct WellbeingNudge {
    public var pattern: WellbeingPattern
    public init(pattern: WellbeingPattern) { self.pattern = pattern }
}

/// What taking a card's action did.
public enum WellbeingActionOutcome: Equatable {
    /// Tomorrow's capacity was set to low.
    case capacityLowered(CalendarDate)
    /// That weekday's default level was set to low.
    case weekdayLowered(Int)
    /// The normal day was set to the recent average, in minutes.
    case normalDayChanged(Int)
    /// Open the habit's pause or edit sheet; nothing was written.
    case openHabit(Habit)
    case nothing

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.capacityLowered(let a), .capacityLowered(let b)): a == b
        case (.weekdayLowered(let a), .weekdayLowered(let b)): a == b
        case (.normalDayChanged(let a), .normalDayChanged(let b)): a == b
        case (.openHabit(let a), .openHabit(let b)): a.id == b.id
        case (.nothing, .nothing): true
        default: false
        }
    }
}

/// Module 5, part 2: the patterns, the one action each, and delivery as an inline card
/// (docs/architecture/rules-engine.md). Never a notification.
extension Wellbeing {

    /// How long a pattern rests after *Not now* (or after its action is taken).
    static let cooldown: TimeInterval = 7 * 24 * 60 * 60

    // MARK: Patterns

    /// The patterns active now, in priority order. None while still gathering data.
    ///
    /// - `heavyRun`: three or more consecutive days ending yesterday, each overloaded.
    /// - `completionCollapse`: the last three days that had something to finish average under half of the
    ///   fortnight before them (which needs at least three such days) and under 40%.
    /// - `weekendOverplan`: a weekend day overloaded on two of the last three finished weekends.
    /// - `habitNeglect`: a habit missed on each of its last three scheduled days. Paused, archived,
    ///   "N times a week" and avoid habits are never neglected.
    @MainActor
    public static func patterns(now: Date, boundary: DayBoundary, firstWeekday: Int = 1, context: ModelContext) throws -> [WellbeingPattern] {
        let history = try History(now: now, boundary: boundary, firstWeekday: firstWeekday, context: context)
        let yesterday = history.today.addingDays(-1)
        guard history.evaluate(endingOn: yesterday).activeDays.count >= minimumActiveDays else { return [] }

        var found: [WellbeingPattern] = []
        if heavyRun(history, yesterday: yesterday) {
            found.append(WellbeingPattern(kind: .heavyRun, subjectKey: "heavyRun"))
        }
        if completionCollapse(history, yesterday: yesterday) {
            found.append(WellbeingPattern(kind: .completionCollapse, subjectKey: "completionCollapse"))
        }
        if let weekday = weekendOverplan(history) {
            found.append(WellbeingPattern(kind: .weekendOverplan, subjectKey: "weekendOverplan:\(weekday)", weekday: weekday))
        }
        for habit in neglectedHabits(history, yesterday: yesterday) {
            found.append(WellbeingPattern(kind: .habitNeglect, subjectKey: "habitNeglect:\(habit.id.uuidString)", habit: habit))
        }
        return found
    }

    /// Strained when any pattern is active, otherwise steady.
    public static func isStrained(_ patterns: [WellbeingPattern]) -> Bool { !patterns.isEmpty }

    @MainActor
    private static func heavyRun(_ history: History, yesterday: CalendarDate) -> Bool {
        var day = yesterday, run = 0
        while history.plans[day]?.wasOverloaded == true { run += 1; day = day.addingDays(-1) }
        return run >= 3
    }

    @MainActor
    private static func completionCollapse(_ history: History, yesterday: CalendarDate) -> Bool {
        let counted = history.plans
            .filter { $0.key <= yesterday && $0.value.completionBasis > 0 }
            .sorted { $0.key > $1.key }
        guard counted.count >= 3 else { return false }
        let recent = Array(counted.prefix(3))
        guard let oldest = recent.last?.key, oldest >= yesterday.addingDays(-(windowDays - 1)) else { return false }
        let prior = counted.filter { $0.key < oldest && $0.key >= oldest.addingDays(-windowDays) }
        guard prior.count >= 3 else { return false }
        let recentMean = recent.map(\.value.completionRate).reduce(0, +) / 3
        let priorMean = prior.map(\.value.completionRate).reduce(0, +) / Double(prior.count)
        return recentMean < 0.5 * priorMean && recentMean < 0.4
    }

    /// The weekend day to lighten, if a weekend day was overloaded on two of the last three finished weekends.
    @MainActor
    private static func weekendOverplan(_ history: History) -> Int? {
        var saturday = history.today.addingDays(-1)
        var steps = 0
        while !(saturday.isoWeekday == 6 && saturday.addingDays(1) < history.today), steps < 14 {
            saturday = saturday.addingDays(-1)
            steps += 1
        }
        guard saturday.isoWeekday == 6 else { return nil }
        var overloadedWeekends = 0
        var saturdays = 0, sundays = 0
        for weekend in 0..<3 {
            let sat = saturday.addingDays(-7 * weekend)
            let satHeavy = history.plans[sat]?.wasOverloaded == true
            let sunHeavy = history.plans[sat.addingDays(1)]?.wasOverloaded == true
            if satHeavy || sunHeavy { overloadedWeekends += 1 }
            if satHeavy { saturdays += 1 }
            if sunHeavy { sundays += 1 }
        }
        guard overloadedWeekends >= 2 else { return nil }
        return sundays > saturdays ? 7 : 6
    }

    @MainActor
    private static func neglectedHabits(_ history: History, yesterday: CalendarDate) -> [Habit] {
        history.habits
            .filter { $0.targetPerWeek == 0 && $0.habitKind != .avoid && !$0.isPaused(on: yesterday) && !$0.isPaused(on: history.today) }
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
            .filter { habit in
                let created = history.boundary.logicalDate(at: habit.createdAt)
                var scheduled: [CalendarDate] = []
                var day = yesterday
                for _ in 0..<90 where scheduled.count < 3 && day >= created {
                    if HabitSchedule.isScheduled(habit, on: day), !habit.isPaused(on: day) { scheduled.append(day) }
                    day = day.addingDays(-1)
                }
                guard scheduled.count == 3, let windows = habit.windows, !windows.isEmpty else { return false }
                return scheduled.allSatisfy { date in
                    windows.allSatisfy { HabitDensity.state(of: $0, on: date, context: history.habitContext) == .missed }
                }
            }
    }

    // MARK: Delivery

    /// The card to show now, or `nil`. One a day (once one is shown, only that one remains today),
    /// a pattern rests for seven days after *Not now*, and a preference turns the cards off.
    @MainActor
    public static func currentNudge(
        patterns: [WellbeingPattern], now: Date, boundary: DayBoundary, nudgesEnabled: Bool, context: ModelContext
    ) throws -> WellbeingNudge? {
        guard nudgesEnabled else { return nil }
        let today = boundary.logicalDate(at: now)
        let logs = try wellbeingLogs(in: context)
        let candidates = patterns.filter { pattern in
            !logs.contains { $0.subjectKey == pattern.subjectKey && ($0.dismissedAt.map { now.timeIntervalSince($0) < cooldown } ?? false) }
        }
        if let shown = logs.first(where: { boundary.logicalDate(at: $0.sentAt) == today }) {
            return candidates.first { $0.subjectKey == shown.subjectKey }.map(WellbeingNudge.init)
        }
        return candidates.first.map(WellbeingNudge.init)
    }

    /// Logs that the card was shown today (once per pattern per day).
    @MainActor
    public static func markShown(_ nudge: WellbeingNudge, now: Date, boundary: DayBoundary, context: ModelContext) throws {
        _ = try todaysLog(for: nudge, now: now, boundary: boundary, context: context)
        try context.save()
    }

    /// *Not now*: the pattern rests for seven days.
    @MainActor
    public static func dismiss(_ nudge: WellbeingNudge, now: Date, boundary: DayBoundary, context: ModelContext) throws {
        try todaysLog(for: nudge, now: now, boundary: boundary, context: context).dismissedAt = now
        try context.save()
    }

    /// Takes the card's one action. It also rests the pattern, like *Not now*, so it isn't offered
    /// again straight away.
    ///
    /// `heavyRun` makes tomorrow a low day; `weekendOverplan` sets that weekday's default to low;
    /// `completionCollapse` sets the normal day to the recent average (the active days of the last
    /// fortnight that had completed effort), rounded to 15 minutes within the slider's range;
    /// `habitNeglect` writes nothing and says which habit to open.
    @MainActor
    @discardableResult
    public static func apply(_ nudge: WellbeingNudge, now: Date, boundary: DayBoundary, context: ModelContext) throws -> WellbeingActionOutcome {
        let today = boundary.logicalDate(at: now)
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        let outcome: WellbeingActionOutcome

        switch nudge.pattern.kind {
        case .heavyRun:
            NightPlanning.setCapacity(.low, forDate: today.addingDays(1), context: context)
            outcome = .capacityLowered(today.addingDays(1))
        case .weekendOverplan:
            let weekday = nudge.pattern.weekday ?? 6
            if let settings { settings.setDefaultLevel(.low, forISOWeekday: weekday); outcome = .weekdayLowered(weekday) } else { outcome = .nothing }
        case .completionCollapse:
            let yesterday = today.addingDays(-1)
            let efforts = try context.fetch(FetchDescriptor<DayPlan>())
                .filter { plan in
                    let day = CalendarDate(storedDate: plan.date)
                    return day <= yesterday && day >= yesterday.addingDays(-(windowDays - 1)) && plan.completedEffortMinutes > 0
                }
                .map(\.completedEffortMinutes)
            if let settings, !efforts.isEmpty {
                let mean = Double(efforts.reduce(0, +)) / Double(efforts.count)
                let minutes = min(360, max(30, Int((mean / 15).rounded()) * 15))
                settings.mediumDayMinutes = minutes
                outcome = .normalDayChanged(minutes)
            } else {
                outcome = .nothing
            }
        case .habitNeglect:
            outcome = nudge.pattern.habit.map { .openHabit($0) } ?? .nothing
        }
        try dismiss(nudge, now: now, boundary: boundary, context: context)
        return outcome
    }

    // MARK: Helpers

    @MainActor
    private static func wellbeingLogs(in context: ModelContext) throws -> [NudgeLog] {
        try context.fetch(FetchDescriptor<NudgeLog>()).filter { $0.nudgeKind == .wellbeing }
    }

    @MainActor
    private static func todaysLog(for nudge: WellbeingNudge, now: Date, boundary: DayBoundary, context: ModelContext) throws -> NudgeLog {
        let today = boundary.logicalDate(at: now)
        if let existing = try wellbeingLogs(in: context).first(where: {
            $0.subjectKey == nudge.pattern.subjectKey && boundary.logicalDate(at: $0.sentAt) == today
        }) { return existing }
        let log = NudgeLog()
        log.nudgeKind = .wellbeing
        log.subjectKey = nudge.pattern.subjectKey
        log.sentAt = now
        context.insert(log)
        return log
    }
}
