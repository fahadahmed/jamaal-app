import Foundation
import SwiftData

/// What a dedup pass changed.
public struct DedupReport: Equatable, Sendable {
    /// Rows deleted as duplicates.
    public var removed = 0
    /// Live sessions closed as `abandoned` because another was already running (a cross-device
    /// clash). The caller shows the single quiet notice (docs/journeys/walkthroughs/03-focus-session.md, G-26).
    public var abandonedSessionIDs: [UUID] = []

    public init(removed: Int = 0, abandonedSessionIDs: [UUID] = []) {
        self.removed = removed
        self.abandonedSessionIDs = abandonedSessionIDs
    }
}

/// CloudKit can't enforce uniqueness, so two devices can each create the same thing. This applies
/// the dedup keys of docs/schema/overview.md. Every rule is safe to repeat and to apply in any
/// order: a second pass over a settled store changes nothing.
///
/// Where the schema table is silent the choice is documented on the rule.
public enum Dedup {

    @MainActor
    public static func run(in context: ModelContext, now: Date) throws -> DedupReport {
        var report = DedupReport()
        // Each step saves, so the next step's fetch never sees a row an earlier step deleted.
        try settings(context, &report)
        try categories(context, &report)
        try repeatingTasks(context, &report)
        try deferrals(context, &report)
        try sessions(context, now, &report)
        try habitEntries(context, &report)
        try anchors(context, &report)
        try dayPlans(context, &report)
        try planningSessions(context, &report)
        return report
    }

    // MARK: Helpers

    private static func dayKey(_ date: Date) -> String { CalendarDate(storedDate: date).isoString }

    /// Groups of two or more items sharing a key; items with a `nil` key never group.
    private static func duplicateGroups<T, K: Hashable>(_ items: [T], key: (T) -> K?) -> [[T]] {
        var groups: [K: [T]] = [:]
        var order: [K] = []
        for item in items {
            guard let k = key(item) else { continue }
            if groups[k] == nil { order.append(k) }
            groups[k, default: []].append(item)
        }
        return order.compactMap { groups[$0] }.filter { $0.count > 1 }
    }

    private static func idOrder(_ a: UUID, _ b: UUID) -> Bool { a.uuidString < b.uuidString }

    private static func delete<T: PersistentModel>(_ items: some Sequence<T>, _ context: ModelContext, _ report: inout DedupReport) {
        for item in items {
            context.delete(item)
            report.removed += 1
        }
    }

    // MARK: UserSettings — a single row

    /// Keeps the earliest-created row. It inherits what it lacks from the others: the earliest
    /// `firstLaunchAt`, and the earliest `onboardingCompletedAt` (so a second device still
    /// recognises an account that has already been through onboarding).
    @MainActor
    private static func settings(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<UserSettings>())
        guard rows.count > 1 else { return }
        let sorted = rows.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        let survivor = sorted[0]
        survivor.firstLaunchAt = rows.compactMap(\.firstLaunchAt).min()
        survivor.onboardingCompletedAt = rows.compactMap(\.onboardingCompletedAt).min()
        delete(sorted.dropFirst(), context, &report)
        try context.save()
    }

    // MARK: TaskCategory — presetKey, else the normalised name

    private static func normalised(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive], locale: nil)
    }

    /// Keeps the earliest and moves the tasks onto it. A category has no settings of its own, so
    /// merging identical labels loses nothing. An unnamed category is mid-creation and never merged.
    @MainActor
    private static func categories(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<TaskCategory>())
        let groups = duplicateGroups(rows) { (c: TaskCategory) -> String? in
            if let preset = c.presetKey { return "preset:\(preset)" }
            let name = normalised(c.name)
            return name.isEmpty ? nil : "name:\(name)"
        }
        guard !groups.isEmpty else { return }
        for group in groups {
            let sorted = group.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
            let survivor = sorted[0]
            for duplicate in sorted.dropFirst() {
                for task in duplicate.tasks ?? [] { task.category = survivor }
            }
            delete(sorted.dropFirst(), context, &report)
        }
        try context.save()
    }

    // MARK: TaskItem — (seriesID, dueDate) for a repeating task's next instance

    /// Keeps the earliest-created instance. Tasks without a series are never merged.
    @MainActor
    private static func repeatingTasks(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<TaskItem>())
        let groups = duplicateGroups(rows) { (t: TaskItem) -> String? in
            guard let series = t.seriesID, let due = t.dueDate else { return nil }
            return "\(series.uuidString)|\(dayKey(due))"
        }
        guard !groups.isEmpty else { return }
        for group in groups {
            let sorted = group.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
            delete(sorted.dropFirst(), context, &report)
        }
        try context.save()
    }

    // MARK: DeferralRecord — (task, day)

    /// One per task per day. The earliest record stays and is refined to the latest choice (its
    /// reason and `deferredTo`); the task's `deferralCount` loses the duplicates' extra increments.
    @MainActor
    private static func deferrals(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<DeferralRecord>())
        let groups = duplicateGroups(rows) { (r: DeferralRecord) -> String? in
            guard let task = r.task else { return nil }
            return "\(task.id.uuidString)|\(dayKey(r.day))"
        }
        guard !groups.isEmpty else { return }
        for group in groups {
            let byTime = group.sorted { ($0.deferredOn, $0.id.uuidString) < ($1.deferredOn, $1.id.uuidString) }
            let survivor = byTime[0]
            let latest = byTime[byTime.count - 1]
            if latest.id != survivor.id {
                survivor.reason = latest.reason
                survivor.deferredTo = latest.deferredTo
            }
            let extra = byTime.count - 1
            if let task = survivor.task { task.deferralCount = max(0, task.deferralCount - extra) }
            delete(byTime.dropFirst(), context, &report)
        }
        try context.save()
    }

    // MARK: WorkSession — at most one live

    /// The earliest-started live session stays live; each other closes as `abandoned` at `now`,
    /// its time logged (elapsed minus pauses, a current pause counted up to now).
    @MainActor
    private static func sessions(_ context: ModelContext, _ now: Date, _ report: inout DedupReport) throws {
        let live = try context.fetch(FetchDescriptor<WorkSession>())
            .filter { $0.outcome == SessionOutcome.running.rawValue && $0.endedAt == nil }
            .sorted { ($0.startedAt, $0.id.uuidString) < ($1.startedAt, $1.id.uuidString) }
        guard live.count > 1 else { return }
        for session in live.dropFirst() {
            let end = max(now, session.startedAt)
            if let pausedAt = session.pausedAt {
                session.pausedSeconds += max(0, Int(end.timeIntervalSince(pausedAt)))
                session.pausedAt = nil
            }
            let elapsed = Int(end.timeIntervalSince(session.startedAt)) - session.pausedSeconds
            session.actualSeconds = max(0, elapsed)
            session.endedAt = end
            session.outcome = SessionOutcome.abandoned.rawValue
            report.abandonedSessionIDs.append(session.id)
        }
        try context.save()
    }

    // MARK: HabitEntry — (window, date)

    /// Keeps one; `amount` is the larger. Ties prefer an entry that carries a completion time,
    /// and the survivor inherits the earliest completion time if it has none.
    @MainActor
    private static func habitEntries(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<HabitEntry>())
        let groups = duplicateGroups(rows) { (e: HabitEntry) -> String? in
            guard let window = e.window else { return nil }
            return "\(window.id.uuidString)|\(dayKey(e.date))"
        }
        guard !groups.isEmpty else { return }
        for group in groups {
            let sorted = group.sorted { a, b in
                if a.amount != b.amount { return a.amount > b.amount }
                if (a.completedAt != nil) != (b.completedAt != nil) { return a.completedAt != nil }
                return idOrder(a.id, b.id)
            }
            let survivor = sorted[0]
            if survivor.completedAt == nil { survivor.completedAt = group.compactMap(\.completedAt).min() }
            delete(sorted.dropFirst(), context, &report)
        }
        try context.save()
    }

    // MARK: Anchor — (rule, occurrenceDate, slotKey) for generated instances

    /// The schema says "keep the earliest; never resurrect a `skipped` one". A decided instance
    /// (anything but `pending`) is therefore kept in preference to a pending one — deleting it
    /// would throw away something the user did — then the earliest-resolved, then earliest-generated.
    /// One-offs have no key.
    @MainActor
    private static func anchors(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<Anchor>())
        let groups = duplicateGroups(rows) { (a: Anchor) -> String? in
            guard let rule = a.rule else { return nil }
            return "\(rule.id.uuidString)|\(dayKey(a.occurrenceDate))|\(a.slotKey)"
        }
        guard !groups.isEmpty else { return }
        for group in groups {
            let sorted = group.sorted { a, b in
                let aDecided = a.status != .pending, bDecided = b.status != .pending
                if aDecided != bDecided { return aDecided }
                if aDecided, a.resolvedAt != b.resolvedAt {
                    return (a.resolvedAt ?? .distantFuture) < (b.resolvedAt ?? .distantFuture)
                }
                if a.generatedAt != b.generatedAt { return a.generatedAt < b.generatedAt }
                return idOrder(a.id, b.id)
            }
            delete(sorted.dropFirst(), context, &report)
        }
        try context.save()
    }

    // MARK: DayPlan — date

    /// Keeps the one with `planningCompletedAt` (the latest if several). `DayPlan` has no
    /// timestamp to say which is "most recent", so otherwise the one with the most completed
    /// effort wins, then the lowest id, which is deterministic if arbitrary.
    @MainActor
    private static func dayPlans(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<DayPlan>())
        let groups = duplicateGroups(rows) { dayKey($0.date) }
        guard !groups.isEmpty else { return }
        for group in groups {
            let sorted = group.sorted { a, b in
                if a.planningCompletedAt != b.planningCompletedAt {
                    return (a.planningCompletedAt ?? .distantPast) > (b.planningCompletedAt ?? .distantPast)
                }
                if a.completedEffortMinutes != b.completedEffortMinutes {
                    return a.completedEffortMinutes > b.completedEffortMinutes
                }
                return idOrder(a.id, b.id)
            }
            delete(sorted.dropFirst(), context, &report)
        }
        try context.save()
    }

    // MARK: NightPlanningSession — forDate

    /// Prefers a complete session, then the furthest step, then the latest created.
    @MainActor
    private static func planningSessions(_ context: ModelContext, _ report: inout DedupReport) throws {
        let rows = try context.fetch(FetchDescriptor<NightPlanningSession>())
        let groups = duplicateGroups(rows) { dayKey($0.forDate) }
        guard !groups.isEmpty else { return }
        let steps = PlanningStep.allCases.filter { !$0.isUnknown }
        func rank(_ s: NightPlanningSession) -> Int { steps.firstIndex(of: s.step) ?? -1 }
        for group in groups {
            let sorted = group.sorted { a, b in
                if a.isComplete != b.isComplete { return a.isComplete }
                if rank(a) != rank(b) { return rank(a) > rank(b) }
                if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
                return idOrder(a.id, b.id)
            }
            delete(sorted.dropFirst(), context, &report)
        }
        try context.save()
    }
}
