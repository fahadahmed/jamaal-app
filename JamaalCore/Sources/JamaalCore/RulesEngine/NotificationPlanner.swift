import Foundation
import SwiftData

/// What a planned notification says. A separate message layer phrases these in Jamaal's voice.
public enum NotificationKind: Equatable, Sendable {
    /// A quiet reminder near the trial's end (`day` is the trial day: 12, 14 or 15).
    case trialEnding(day: Int)
    /// The evening prompt to plan `forDate`.
    case planningPrompt(forDate: CalendarDate)
    case morningNudge
    /// An Anchor's window opens (`leadMinutes` before it; 0 = at the start).
    case anchorStart(title: String, leadMinutes: Int)
    /// An Anchor's window closes in `minutesBefore` minutes.
    case anchorClosing(title: String, minutesBefore: Int)
    case habitReminder(title: String)
}

/// One local notification to schedule. `id` is stable, so the app can diff the plan against what is pending.
public struct PlannedNotification: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var kind: NotificationKind
    var priority: Int
}

public struct PlannerInputs: Sendable {
    public var now: Date
    public var boundary: DayBoundary
    public var access: AccessState
    /// When the trial began; needed for the trial-end reminders.
    public var trialStart: CalendarDate?
    /// The system's notification permission is granted.
    public var permissionGranted: Bool
    /// This device's "Send reminders on this device" switch (local; on for iPhone, off for iPad and Mac).
    public var remindersOnThisDevice: Bool
    /// The optional morning nudge (a per-device preference).
    public var morningNudgeEnabled: Bool

    public init(
        now: Date, boundary: DayBoundary, access: AccessState, trialStart: CalendarDate? = nil,
        permissionGranted: Bool, remindersOnThisDevice: Bool, morningNudgeEnabled: Bool
    ) {
        self.now = now
        self.boundary = boundary
        self.access = access
        self.trialStart = trialStart
        self.permissionGranted = permissionGranted
        self.remindersOnThisDevice = remindersOnThisDevice
        self.morningNudgeEnabled = morningNudgeEnabled
    }
}

/// Module 6: the one planner behind every local notification (docs/architecture/rules-engine.md).
///
/// iOS keeps at most 64 pending local notifications, so the planner builds the upcoming schedule in
/// priority order and stops at 60: trial-end reminders, the evening planning prompt, the morning nudge,
/// Anchor reminders, then habit reminders. It is pure; the app diffs the result against the pending
/// requests (by `id`) on launch, on foreground and on background refresh. Nothing nags: sessions and
/// wellbeing cards never produce a notification.
public enum NotificationPlanner {

    /// Slots used; the system allows 64.
    public static let budget = 60
    /// Nights of evening prompts and mornings of nudges planned ahead.
    static let planningHorizonDays = 5
    /// Days of Anchor reminders planned ahead, using the generator's preview rather than only the stored days.
    static let anchorHorizonDays = 5
    /// Days of habit reminders planned (today and tomorrow): near-term, so a logged habit's can be cancelled.
    static let habitHorizonDays = 2
    /// The trial-end reminders go out at 09:00.
    static let trialReminderMinute = 9 * 60

    private enum Priority { static let trial = 0, planning = 1, morning = 2, anchor = 3, habit = 4 }

    @MainActor
    public static func plan(_ inputs: PlannerInputs, context: ModelContext) throws -> [PlannedNotification] {
        // Without permission or with this device's switch off, nothing is scheduled (the trial reminders too).
        guard inputs.permissionGranted, inputs.remindersOnThisDevice else { return [] }
        let now = inputs.now
        let boundary = inputs.boundary
        let today = boundary.logicalDate(at: now)
        var candidates: [PlannedNotification] = []

        func add(_ id: String, _ fire: Date, _ kind: NotificationKind, _ priority: Int) {
            if fire > now { candidates.append(PlannedNotification(id: id, fireDate: fire, kind: kind, priority: priority)) }
        }

        // Trial-end reminders: while not subscribed.
        if inputs.access != .subscribed, let start = inputs.trialStart {
            for (offset, date) in Trial.reminderDates(start: start).enumerated() {
                let day = Trial.reminderDays[offset]
                add("trial:\(day)", boundary.instant(of: date, atMinute: trialReminderMinute), .trialEnding(day: day), Priority.trial)
            }
        }

        // Read-only stops everything else; the engine still runs, only notifications stop.
        if inputs.access.canShapeThePlan {
            let settings = try context.fetch(FetchDescriptor<UserSettings>())
                .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) } ?? UserSettings()
            let sessions = try context.fetch(FetchDescriptor<NightPlanningSession>())

            for offset in 0..<planningHorizonDays {
                let day = today.addingDays(offset)
                let forDate = day.addingDays(1)
                // Once that night is closed or skipped its prompt stops, and is never repeated.
                let settled = sessions.contains { CalendarDate(storedDate: $0.forDate) == forDate && ($0.isComplete || $0.skippedAt != nil) }
                if !settled {
                    add("planning:\(forDate.isoString)", boundary.instant(of: day, atMinute: settings.planningMinute), .planningPrompt(forDate: forDate), Priority.planning)
                }
                if inputs.morningNudgeEnabled {
                    add("morning:\(day.isoString)", boundary.instant(of: day, atMinute: settings.morningMinute), .morningNudge, Priority.morning)
                }
            }

            try addAnchorReminders(today: today, boundary: boundary, context: context, add: add)
            try addHabitReminders(today: today, boundary: boundary, context: context, add: add)
        }

        let chosen = candidates
            .sorted { ($0.priority, $0.fireDate, $0.id) < ($1.priority, $1.fireDate, $1.id) }
            .prefix(budget)
        return chosen.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
    }

    // MARK: Anchors

    private struct AnchorCandidate {
        var key: String
        var title: String
        var windowStart: Date
        var windowEnd: Date
        var remindStart: Int?
        var remindEnd: Int?
    }

    /// Pending Anchors in the next five days: the stored ones, plus what each rule's preview would add
    /// for days not stored yet. A decided Anchor, or one that already has a stored instance, is never duplicated.
    @MainActor
    private static func addAnchorReminders(
        today: CalendarDate, boundary: DayBoundary, context: ModelContext,
        add: (String, Date, NotificationKind, Int) -> Void
    ) throws {
        let horizon = (0..<anchorHorizonDays).map { today.addingDays($0) }
        let stored = try context.fetch(FetchDescriptor<Anchor>())
        var storedKeys = Set<String>()
        var candidates: [AnchorCandidate] = []

        for anchor in stored {
            if let rule = anchor.rule {
                storedKeys.insert("\(rule.id.uuidString)|\(CalendarDate(storedDate: anchor.occurrenceDate).isoString)|\(anchor.slotKey)")
            }
            guard anchor.status == .pending, horizon.contains(CalendarDate(storedDate: anchor.occurrenceDate)) else { continue }
            let title = composed(rule: anchor.rule?.title, slot: anchor.title)
            candidates.append(AnchorCandidate(
                key: anchor.id.uuidString, title: title, windowStart: anchor.windowStart, windowEnd: anchor.windowEnd,
                remindStart: anchor.remindBeforeStartMinutes, remindEnd: anchor.remindBeforeEndMinutes
            ))
        }
        for rule in try context.fetch(FetchDescriptor<AnchorRule>()) {
            for item in AnchorGenerator.preview(rule: rule, days: horizon, boundary: boundary) {
                let key = "\(rule.id.uuidString)|\(item.occurrenceDate.isoString)|\(item.slotKey)"
                guard !storedKeys.contains(key) else { continue }
                candidates.append(AnchorCandidate(
                    key: key, title: composed(rule: rule.title, slot: item.title), windowStart: item.windowStart, windowEnd: item.windowEnd,
                    remindStart: item.remindBeforeStartMinutes, remindEnd: item.remindBeforeEndMinutes
                ))
            }
        }
        for candidate in candidates {
            if let lead = candidate.remindStart {
                add("anchor:\(candidate.key):start", candidate.windowStart.addingTimeInterval(-Double(lead) * 60),
                    .anchorStart(title: candidate.title, leadMinutes: lead), Priority.anchor)
            }
            if let before = candidate.remindEnd {
                add("anchor:\(candidate.key):end", candidate.windowEnd.addingTimeInterval(-Double(before) * 60),
                    .anchorClosing(title: candidate.title, minutesBefore: before), Priority.anchor)
            }
        }
    }

    /// "School run · Drop-off" when the slot label differs from the rule's title.
    private static func composed(rule: String?, slot: String) -> String {
        guard let rule, !rule.isEmpty, rule != slot, !slot.isEmpty else { return slot.isEmpty ? (rule ?? "") : slot }
        return "\(rule) · \(slot)"
    }

    // MARK: Habits

    /// A due, unfinished window with a reminder time, today and tomorrow. A habit that is logged,
    /// paused or archived, or a "N times a week" habit whose week is met, makes none.
    @MainActor
    private static func addHabitReminders(
        today: CalendarDate, boundary: DayBoundary, context: ModelContext,
        add: (String, Date, NotificationKind, Int) -> Void
    ) throws {
        let habits = try context.fetch(FetchDescriptor<Habit>())
        for offset in 0..<habitHorizonDays {
            let day = today.addingDays(offset)
            let due = HabitToday.dueWindows(of: habits, context: HabitContext(boundary: boundary, today: day))
            for item in due where !item.isDone {
                guard let minute = item.window.reminderMinute else { continue }
                add("habit:\(item.window.id.uuidString):\(day.isoString)", boundary.instant(of: day, atMinute: minute),
                    .habitReminder(title: item.habit.title), Priority.habit)
            }
        }
    }
}
