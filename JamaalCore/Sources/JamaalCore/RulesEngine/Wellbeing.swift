import Foundation
import SwiftData

public enum WellbeingPartKind: Sendable { case tasks, anchors, habits, load }

/// One of the score's parts, 0–100, with its weight.
public struct WellbeingPart: Equatable, Sendable {
    public var kind: WellbeingPartKind
    public var value: Double
    public var weight: Double

    public init(kind: WellbeingPartKind, value: Double, weight: Double) {
        self.kind = kind
        self.value = value
        self.weight = weight
    }
}

/// How the score has moved against 14 days earlier, in words, never as a coloured number.
public enum WellbeingTrend: Sendable { case steadier, aboutTheSame, heavier }

public enum WellbeingState: Equatable, Sendable {
    /// Fewer than seven active days in the last fourteen: nothing useful to say yet.
    case gathering(activeDays: Int, needed: Int)
    case active(score: Int, trend: WellbeingTrend?)
}

public struct SparkPoint: Equatable, Sendable {
    public var day: CalendarDate
    /// `nil` where the point's own window has fewer than seven active days.
    public var score: Int?

    public init(day: CalendarDate, score: Int?) {
        self.day = day
        self.score = score
    }
}

public struct WellbeingSnapshot {
    public var state: WellbeingState
    /// Active days in the last fourteen logical days.
    public var activeDays: Int
    public var parts: [WellbeingPart]
    /// The score at each of the last 14 days, each over its own trailing 14.
    public var sparkline: [SparkPoint]
    /// The tasks part as a whole percentage, if any day had tasks to finish.
    public var completionPercent: Int?
    /// Active days in the window that were overloaded.
    public var heavyDays: Int
    /// Over the window's active days: tasks finished, and tasks that had to be finished (finished plus moved, deferred
    /// or dropped). Zero while gathering data.
    public var tasksDone: Int
    public var tasksToFinish: Int
    /// Anchors attended, and attended plus missed (skipped and delegated aren't counted). Zero while gathering data.
    public var anchorsAttended: Int
    public var anchorsDecided: Int

    public init(
        state: WellbeingState, activeDays: Int, parts: [WellbeingPart], sparkline: [SparkPoint], completionPercent: Int?, heavyDays: Int,
        tasksDone: Int, tasksToFinish: Int, anchorsAttended: Int, anchorsDecided: Int
    ) {
        self.state = state
        self.activeDays = activeDays
        self.parts = parts
        self.sparkline = sparkline
        self.completionPercent = completionPercent
        self.heavyDays = heavyDays
        self.tasksDone = tasksDone
        self.tasksToFinish = tasksToFinish
        self.anchorsAttended = anchorsAttended
        self.anchorsDecided = anchorsDecided
    }
}

/// Module 5: wellbeing, derived only from behaviour — no self-reporting, nothing stored
/// (docs/architecture/rules-engine.md). Part 1: the score, the gathering-data state, the sparkline
/// and the trend.
///
/// An **active day** is a logical day with a `DayPlan` (the rollover creates one for any day with
/// activity). The score is a whole number 0–100 over the last 14 logical days **ending yesterday**
/// (today isn't finished), averaged over active days from four parts: **tasks 35%** (mean
/// completion rate, leaving out days with nothing to finish), **Anchors 25%** (attended over
/// attended plus missed, with skipped and delegated left out and a closed, still-pending Anchor
/// read as missed), **habits 20%** (mean density of due windows, plus each full week of a
/// "N times a week" habit) and **load 20%** (the share of active days that weren't overloaded). A
/// part with no data drops out and the rest are scaled up, so having no Anchors never costs anything.
public enum Wellbeing {

    static let windowDays = 14
    static let minimumActiveDays = 7
    /// Points of score that count as a change in the trend.
    static let trendThreshold = 5
    static let weights: [WellbeingPartKind: Double] = [.tasks: 35, .anchors: 25, .habits: 20, .load: 20]

    @MainActor
    public static func snapshot(now: Date, boundary: DayBoundary, firstWeekday: Int = 1, context: ModelContext) throws -> WellbeingSnapshot {
        let history = try History(now: now, boundary: boundary, firstWeekday: firstWeekday, context: context)
        let yesterday = history.today.addingDays(-1)

        let current = history.evaluate(endingOn: yesterday)
        let previous = history.evaluate(endingOn: yesterday.addingDays(-windowDays))
        let sparkline = (0..<windowDays).reversed().map { offset -> SparkPoint in
            let day = yesterday.addingDays(-offset)
            return SparkPoint(day: day, score: history.evaluate(endingOn: day).scoreIfActive)
        }

        let state: WellbeingState
        if let score = current.scoreIfActive {
            var trend: WellbeingTrend?
            if let before = previous.scoreIfActive {
                let change = score - before
                trend = change >= trendThreshold ? .steadier : change <= -trendThreshold ? .heavier : .aboutTheSame
            }
            state = .active(score: score, trend: trend)
        } else {
            state = .gathering(activeDays: current.activeDays.count, needed: minimumActiveDays)
        }

        return WellbeingSnapshot(
            state: state,
            activeDays: current.activeDays.count,
            parts: current.parts,
            sparkline: sparkline,
            completionPercent: current.parts.first { $0.kind == .tasks }.map { Int($0.value.rounded()) },
            heavyDays: current.activeDays.filter { history.plans[$0]?.wasOverloaded == true }.count,
            tasksDone: current.tasksDone, tasksToFinish: current.tasksToFinish,
            anchorsAttended: current.anchorsAttended, anchorsDecided: current.anchorsDecided
        )
    }

    // MARK: The history, loaded once

    struct Evaluation {
        var activeDays: [CalendarDate]
        var parts: [WellbeingPart]
        var tasksDone = 0
        var tasksToFinish = 0
        var anchorsAttended = 0
        var anchorsDecided = 0

        /// The weighted score, only once the window has enough active days.
        var scoreIfActive: Int? {
            guard activeDays.count >= Wellbeing.minimumActiveDays, !parts.isEmpty else { return nil }
            let total = parts.reduce(0) { $0 + $1.weight }
            return Int((parts.reduce(0) { $0 + $1.value * $1.weight } / total).rounded())
        }
    }

    @MainActor
    struct History {
        let today: CalendarDate
        let boundary: DayBoundary
        let now: Date
        let firstWeekday: Int
        var plans: [CalendarDate: DayPlan] = [:]
        var anchorsByDay: [CalendarDate: [Anchor]] = [:]
        var habits: [Habit] = []
        let habitContext: HabitContext

        init(now: Date, boundary: DayBoundary, firstWeekday: Int, context: ModelContext) throws {
            self.now = now
            self.boundary = boundary
            self.firstWeekday = firstWeekday
            today = boundary.logicalDate(at: now)
            for plan in try context.fetch(FetchDescriptor<DayPlan>()).sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                let day = CalendarDate(storedDate: plan.date)
                if plans[day] == nil { plans[day] = plan }
            }
            for anchor in try context.fetch(FetchDescriptor<Anchor>()) {
                anchorsByDay[CalendarDate(storedDate: anchor.occurrenceDate), default: []].append(anchor)
            }
            habits = try context.fetch(FetchDescriptor<Habit>()).filter { !$0.isArchived }
            habitContext = HabitContext(
                boundary: boundary, today: today, firstWeekday: firstWeekday,
                engagedDays: try Engagement.engagedDays(in: context, boundary: boundary)
            )
        }

        func evaluate(endingOn end: CalendarDate) -> Evaluation {
            let days = (0..<Wellbeing.windowDays).map { end.addingDays($0 - Wellbeing.windowDays + 1) }
            let active = days.filter { plans[$0] != nil }
            var parts: [WellbeingPart] = []
            guard active.count >= Wellbeing.minimumActiveDays else { return Evaluation(activeDays: active, parts: []) }

            func add(_ kind: WellbeingPartKind, _ value: Double?) {
                if let value { parts.append(WellbeingPart(kind: kind, value: value, weight: Wellbeing.weights[kind] ?? 0)) }
            }
            add(.tasks, mean(active.compactMap { day in plans[day].flatMap { $0.completionBasis > 0 ? $0.completionRate : nil } }).map { $0 * 100 })
            add(.anchors, anchorsPart(over: active))
            add(.habits, habitsPart(activeDays: active, window: days))
            add(.load, Double(active.filter { plans[$0]?.wasOverloaded != true }.count) / Double(active.count) * 100)
            var result = Evaluation(activeDays: active, parts: parts)
            for day in active {
                if let plan = plans[day], plan.completionBasis > 0 {
                    result.tasksToFinish += plan.completionBasis
                    result.tasksDone += Int((plan.completionRate * Double(plan.completionBasis)).rounded())
                }
                let statuses = (anchorsByDay[day] ?? []).map { AnchorAttendance.displayStatus(of: $0, at: now) }
                let attended = statuses.filter { $0 == .attended }.count
                result.anchorsAttended += attended
                result.anchorsDecided += attended + statuses.filter { $0 == .missed }.count
            }
            return result
        }

        private func mean(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }

        /// Per active day, attended over attended plus missed; a closed pending Anchor reads as missed.
        private func anchorsPart(over days: [CalendarDate]) -> Double? {
            let ratios: [Double] = days.compactMap { day in
                let statuses = (anchorsByDay[day] ?? []).map { AnchorAttendance.displayStatus(of: $0, at: now) }
                let attended = statuses.filter { $0 == .attended }.count
                let missed = statuses.filter { $0 == .missed }.count
                return attended + missed == 0 ? nil : Double(attended) / Double(attended + missed)
            }
            return mean(ratios).map { $0 * 100 }
        }

        /// Pooled: each due window on each active day (complete 1, partial its share, missed 0), plus each
        /// full week of a "N times a week" habit. Paused, unscheduled and unresolved days aren't due.
        private func habitsPart(activeDays: [CalendarDate], window: [CalendarDate]) -> Double? {
            var items: [Double] = []
            for habit in habits {
                if habit.targetPerWeek > 0 { items += weeklyItems(for: habit, window: window); continue }
                for day in activeDays {
                    for habitWindow in habit.windows ?? [] {
                        switch HabitDensity.state(of: habitWindow, on: day, context: habitContext) {
                        case .complete: items.append(1)
                        case .missed: items.append(0)
                        case .partialLow, .partialHigh:
                            let entry = HabitWindowAccess.entry(of: habitWindow, on: day)
                            items.append(min(1, Double(entry?.amount ?? 0) / Double(max(1, entry?.target ?? habitWindow.target))))
                        case .empty: break
                        }
                    }
                }
            }
            return mean(items).map { $0 * 100 }
        }

        private func weeklyItems(for habit: Habit, window: [CalendarDate]) -> [Double] {
            guard let first = window.first, let last = window.last else { return [] }
            var items: [Double] = []
            for day in window {
                let weekStart = day.addingDays(-((day.isoWeekday - firstWeekday + 7) % 7))
                guard weekStart == day, weekStart >= first, weekStart.addingDays(6) <= last,
                      weekStart >= boundary.logicalDate(at: habit.createdAt),
                      let progress = HabitSchedule.weeklyProgress(of: habit, on: weekStart, context: habitContext) else { continue }
                items.append(min(1, Double(progress.done) / Double(max(1, progress.target))))
            }
            return items
        }
    }
}
