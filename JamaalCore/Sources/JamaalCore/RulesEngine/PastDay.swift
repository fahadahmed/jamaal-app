import Foundation
import SwiftData

/// What happened to a task on a reviewed day.
public enum PastTaskOutcome: Equatable {
    case done(at: Date)
    /// Moved by the user ("Deferred to Wed 14"); `nil` is Someday.
    case deferred(to: CalendarDate?)
    /// Moved by the rollover because it wasn't handled ("Not done · carried to Tue 13").
    case carried(to: CalendarDate?)
    /// Due that day and still waiting, because the rollover hasn't moved it yet.
    case notDone
}

public struct PastTask {
    public var task: TaskItem
    public var outcome: PastTaskOutcome
    /// Whether **Mark done** is offered: only a not-done task, only inside the two-day fix window.
    public var canMarkDone: Bool
}

/// What Today's **Yesterday** row says.
public enum YesterdayRow: Equatable {
    /// No data at all yet (the first day).
    case hidden
    /// Yesterday wasn't a planned day.
    case notPlanned
    case summary(done: Int, planned: Int)
}

/// The previous and next day Day review's arrows go to.
public struct PastDayNeighbours: Equatable {
    public var previous: CalendarDate?
    public var next: CalendarDate?

    public init(previous: CalendarDate? = nil, next: CalendarDate? = nil) {
        self.previous = previous
        self.next = next
    }
}

/// **Day review** (docs/journeys/coming-up-and-day-review.md): one closed day, read-only, **derived** from what is
/// already stored (`DayPlan`, task times and deferral records, Anchor instances, habit entries), so it adds no data
/// and no CloudKit schema. Complements `NightPlanning.review`, which reads the day just ending; this reads any past day.
public struct PastDay {
    /// A missed task can be ticked for this many days back (yesterday and the day before). Habits keep their own
    /// 14-day correction rule (`HabitLogging.canCorrect`), and Anchors theirs (*Mark as done after all*).
    public static let fixWindowDays = 2

    public var date: CalendarDate
    public var level: CapacityLevel
    public var budgetMinutes: Int
    /// Effort of the day as lived: the day record's, else the done tasks' estimates.
    public var usedMinutes: Int
    /// When the day was closed in Night Planning; `nil` if it wasn't.
    public var closedAt: Date?
    /// Done first, then deferred, then not done or carried.
    public var tasks: [PastTask]
    public var anchors: [AnchorReview]
    public var habits: [HabitReview]

    public var doneCount: Int { tasks.filter { if case .done = $0.outcome { true } else { false } }.count }
    /// Done plus not done; a dropped task is neither.
    public var plannedCount: Int { tasks.count }
    public var anchorsAttended: Int { anchors.filter { $0.status == .attended }.count }
    /// Anchors still counting: skipped and delegated ones are neither attended nor missed.
    public var anchorsCounted: Int { anchors.filter { $0.status != .skipped && $0.status != .delegated }.count }

    public static func canFixTasks(on day: CalendarDate, today: CalendarDate) -> Bool {
        let back = today.days(until: day)
        return back < 0 && back >= -fixWindowDays
    }

    @MainActor
    public static func read(on day: CalendarDate, today: CalendarDate, boundary: DayBoundary, now: Date, context: ModelContext) throws -> PastDay {
        func logical(_ instant: Date) -> CalendarDate { boundary.logicalDate(at: instant) }
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        var listed: [(rank: Int, sort: Date, id: String, entry: PastTask)] = []
        var usedFromTasks = 0
        let canFix = canFixTasks(on: day, today: today)

        for task in tasks {
            if task.isCompleted, let completedAt = task.completedAt, logical(completedAt) == day {
                usedFromTasks += task.effortMinutes ?? 0
                listed.append((0, completedAt, task.id.uuidString, PastTask(task: task, outcome: .done(at: completedAt), canMarkDone: false)))
                continue
            }
            guard task.droppedAt.map(logical) != day else { continue }
            if let record = (task.deferrals ?? []).first(where: { CalendarDate(storedDate: $0.day) == day }) {
                let to = record.deferredTo.map { CalendarDate(storedDate: $0) }
                let automatic = record.reasonKind == .unspecified
                let outcome: PastTaskOutcome = automatic ? .carried(to: to) : .deferred(to: to)
                let open = !task.isCompleted && task.droppedAt == nil
                listed.append((automatic ? 2 : 1, task.createdAt, task.id.uuidString, PastTask(task: task, outcome: outcome, canMarkDone: canFix && open)))
            } else if !task.isCompleted, task.droppedAt == nil, day < today,
                      task.dueDate.map({ CalendarDate(storedDate: $0) == day }) == true {
                listed.append((2, task.createdAt, task.id.uuidString, PastTask(task: task, outcome: .notDone, canMarkDone: canFix)))
            }
        }
        listed.sort { ($0.rank, $0.sort, $0.id) < ($1.rank, $1.sort, $1.id) }

        let plan = try context.fetch(FetchDescriptor<DayPlan>())
            .filter { logical($0.date) == day || CalendarDate(storedDate: $0.date) == day }
            .min { $0.id.uuidString < $1.id.uuidString }
        let level = try TodayDay.level(on: day, in: context)
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) } ?? UserSettings()
        let closing = try context.fetch(FetchDescriptor<NightPlanningSession>())
            .filter { $0.isComplete && CalendarDate(storedDate: $0.forDate) == day.addingDays(1) }
            .compactMap(\.completedAt).min()

        let review = try NightPlanning.review(reviewDate: day, boundary: boundary, now: now, context: context)
        return PastDay(
            date: day, level: level,
            budgetMinutes: CapacityLoad.budgetMinutes(for: level, mediumDayMinutes: settings.mediumDayMinutes),
            usedMinutes: plan?.completedEffortMinutes ?? usedFromTasks,
            closedAt: closing, tasks: listed.map(\.entry), anchors: review.anchors, habits: review.habits
        )
    }

    // MARK: Navigation and the Yesterday row

    /// The earliest day before `today` that has any data (a day record, a task, a habit or an Anchor); `nil` on the
    /// first day, when there is nothing to look back at.
    @MainActor
    public static func firstDay(before today: CalendarDate, boundary: DayBoundary, context: ModelContext) throws -> CalendarDate? {
        var days: [CalendarDate] = []
        days += try context.fetch(FetchDescriptor<DayPlan>()).map { CalendarDate(storedDate: $0.date) }
        days += try context.fetch(FetchDescriptor<TaskItem>()).map { boundary.logicalDate(at: $0.createdAt) }
        days += try context.fetch(FetchDescriptor<Habit>()).map { boundary.logicalDate(at: $0.createdAt) }
        days += try context.fetch(FetchDescriptor<Anchor>()).map { CalendarDate(storedDate: $0.occurrenceDate) }
        return days.filter { $0 < today }.min()
    }

    /// Previous goes back to the first day with data, uncapped; next stops at yesterday (today has its own screen).
    @MainActor
    public static func neighbours(of day: CalendarDate, today: CalendarDate, boundary: DayBoundary, context: ModelContext) throws -> PastDayNeighbours {
        let first = try firstDay(before: today, boundary: boundary, context: context)
        let previous = first.flatMap { day > $0 ? day.addingDays(-1) : nil }
        let next = day.addingDays(1) < today ? day.addingDays(1) : nil
        return PastDayNeighbours(previous: previous, next: next)
    }

    @MainActor
    public static func yesterdayRow(today: CalendarDate, boundary: DayBoundary, context: ModelContext) throws -> YesterdayRow {
        let yesterday = today.addingDays(-1)
        guard let first = try firstDay(before: today, boundary: boundary, context: context), first <= yesterday else { return .hidden }
        let planned = try context.fetch(FetchDescriptor<DayPlan>()).contains {
            CalendarDate(storedDate: $0.date) == yesterday && $0.planningCompletedAt != nil
        } || context.fetch(FetchDescriptor<NightPlanningSession>()).contains {
            $0.isComplete && CalendarDate(storedDate: $0.forDate) == yesterday
        }
        guard planned else { return .notPlanned }
        let day = try read(on: yesterday, today: today, boundary: boundary, now: boundary.startInstant(of: today), context: context)
        return .summary(done: day.doneCount, planned: day.plannedCount)
    }
}
