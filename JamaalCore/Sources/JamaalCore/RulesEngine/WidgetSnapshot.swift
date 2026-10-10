import Foundation
import SwiftData

/// What a widget (and, in v1.1, the watch) shows: Today in one small, Codable, device-independent value
/// (docs/architecture/widgets-and-watch.md). Built from the same reads as Today, so a widget can't say anything
/// the app wouldn't. It carries no SwiftData objects, so the app can hand it to an extension or over
/// WatchConnectivity as JSON, and the view layer phrases it in Jamaal's voice.
public struct WidgetSnapshot: Codable, Equatable, Sendable {

    public enum AnchorPhase: String, Codable, Sendable {
        case upcoming, open, closingSoon
        /// The window has closed and nothing was logged: Today reads it as missed, and offers "done after all" that day.
        case needsAttention
    }

    public struct TaskLine: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var title: String
        public var effortMinutes: Int?
        /// The category's colour key; the widget looks the colour up in its palette. Nil when there is no category.
        public var categoryColorKey: String?

        public init(id: UUID, title: String, effortMinutes: Int?, categoryColorKey: String?) {
            self.id = id; self.title = title; self.effortMinutes = effortMinutes; self.categoryColorKey = categoryColorKey
        }
    }

    public struct Capacity: Codable, Equatable, Sendable {
        public var plannedMinutes: Int
        public var budgetMinutes: Int
        /// `low`, `medium` or `high`.
        public var level: String
        public var state: LoadState

        public init(plannedMinutes: Int, budgetMinutes: Int, level: String, state: LoadState) {
            self.plannedMinutes = plannedMinutes; self.budgetMinutes = budgetMinutes; self.level = level; self.state = state
        }
    }

    public struct AnchorWindow: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        /// The Anchor's own name ("Dhuhr", "Pick-up"); a rule's title is kept apart so a small widget can choose.
        public var name: String
        public var ruleTitle: String?
        public var phase: AnchorPhase
        public var start: Date
        public var end: Date
        /// How far through the window it is, 0…1.
        public var progress: Double

        public init(id: UUID, name: String, ruleTitle: String?, phase: AnchorPhase, start: Date, end: Date, progress: Double) {
            self.id = id; self.name = name; self.ruleTitle = ruleTitle; self.phase = phase
            self.start = start; self.end = end; self.progress = progress
        }
    }

    public var generatedAt: Date
    /// The logical day, as `yyyy-MM-dd`.
    public var day: String
    public var isReadOnly: Bool
    /// Tasks Today shows that aren't done, and those done today.
    public var tasksLeft: Int
    public var tasksDone: Int
    /// The first few of what's left, in Today's own order; `moreTasks` is how many more there are.
    public var tasks: [TaskLine]
    public var moreTasks: Int
    public var capacity: Capacity
    /// Anchors still to attend or needing attention: open ones first, then upcoming, then unmarked ones.
    public var anchors: [AnchorWindow]
    /// The evening planning time today, and whether it has passed.
    public var planningAt: Date
    public var planningDue: Bool
    /// When the logical day rolls over.
    public var dayEndsAt: Date

    public init(
        generatedAt: Date, day: String, isReadOnly: Bool, tasksLeft: Int, tasksDone: Int, tasks: [TaskLine], moreTasks: Int,
        capacity: Capacity, anchors: [AnchorWindow], planningAt: Date, planningDue: Bool, dayEndsAt: Date
    ) {
        self.generatedAt = generatedAt; self.day = day; self.isReadOnly = isReadOnly
        self.tasksLeft = tasksLeft; self.tasksDone = tasksDone; self.tasks = tasks; self.moreTasks = moreTasks
        self.capacity = capacity; self.anchors = anchors
        self.planningAt = planningAt; self.planningDue = planningDue; self.dayEndsAt = dayEndsAt
    }

    /// Nothing planned and nothing done: Today's blank day.
    public var isBlankDay: Bool { tasksLeft == 0 && tasksDone == 0 }
    /// Everything planned is done.
    public var isAllDone: Bool { tasksLeft == 0 && tasksDone > 0 }
    /// The Anchor to lead with: the open one, else the next to open. Never one that already closed unmarked.
    public var nextAnchor: AnchorWindow? { anchors.first { $0.phase != .needsAttention } }
    /// "Plan tomorrow" is offered from the evening time, and not when the app is read-only (planning is locked).
    public var showsPlanTomorrow: Bool { planningDue && !isReadOnly }
}

extension WidgetSnapshot {

    /// Today as a widget needs it. Read-only: it changes nothing, and marks no prompt as shown.
    @MainActor
    public static func make(
        in context: ModelContext, now: Date, access: AccessState, maxTasks: Int = 5, maxAnchors: Int = 3,
        timeZone: TimeZone = .current
    ) throws -> WidgetSnapshot {
        let overview = try TodayDay.overview(in: context, now: now, timeZone: timeZone)
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first ?? UserSettings()
        let boundary = DayBoundary(rolloverMinute: settings.rolloverMinute, timeZone: timeZone)

        let lines = overview.shown.prefix(max(0, maxTasks)).map {
            TaskLine(id: $0.id, title: $0.title, effortMinutes: $0.effortMinutes, categoryColorKey: $0.category?.colorKey)
        }

        let anchors = try anchorWindows(in: context, now: now, boundary: boundary).prefix(max(0, maxAnchors))

        // A planning time before the rollover (01:00 with a 03:00 rollover) falls on the next calendar date.
        let planningDate = settings.planningMinute < settings.rolloverMinute ? overview.today.addingDays(1) : overview.today
        let planningAt = boundary.instant(of: planningDate, atMinute: settings.planningMinute)

        return WidgetSnapshot(
            generatedAt: now, day: overview.today.isoString, isReadOnly: access == .readOnly,
            tasksLeft: overview.shown.count, tasksDone: overview.completedToday.count,
            tasks: Array(lines), moreTasks: max(0, overview.shown.count - lines.count),
            capacity: Capacity(
                plannedMinutes: overview.plannedMinutes, budgetMinutes: overview.budgetMinutes,
                level: overview.level.rawValue, state: overview.state),
            anchors: Array(anchors),
            planningAt: planningAt, planningDue: now >= planningAt,
            dayEndsAt: boundary.startInstant(of: overview.today.addingDays(1))
        )
    }

    @MainActor
    private static func anchorWindows(in context: ModelContext, now: Date, boundary: DayBoundary) throws -> [AnchorWindow] {
        let rows = try TodayAnchors.items(in: context, now: now, boundary: boundary).flatMap { item -> [TodayAnchorRow] in
            switch item {
            case .plain(let row): return [row]
            case .group(let group): return group.members
            }
        }
        return rows.compactMap { row -> (AnchorWindow, Int)? in
            let phase: AnchorPhase
            switch row.status {
            case .pending:
                switch row.state {
                case .upcoming: phase = .upcoming
                case .open: phase = .open
                case .closingSoon: phase = .closingSoon
                case .closed: phase = .needsAttention
                }
            case .missed: phase = .needsAttention
            default: return nil                                       // attended, skipped, delegated: nothing left to do
            }
            let anchor = row.anchor
            let ruleTitle = anchor.rule.map(\.title).flatMap { $0.isEmpty ? nil : $0 }
            let window = AnchorWindow(
                id: anchor.id, name: anchor.title.isEmpty ? (ruleTitle ?? "") : anchor.title, ruleTitle: ruleTitle,
                phase: phase, start: anchor.windowStart, end: anchor.windowEnd, progress: row.progress)
            return (window, phase == .upcoming ? 1 : (phase == .needsAttention ? 2 : 0))
        }
        .sorted { ($0.1, $0.0.start, $0.0.name, $0.0.id.uuidString) < ($1.1, $1.0.start, $1.0.name, $1.0.id.uuidString) }
        .map(\.0)
    }
}
