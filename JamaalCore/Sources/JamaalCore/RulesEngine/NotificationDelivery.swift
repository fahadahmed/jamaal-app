import Foundation
import SwiftData

/// A notification's words, in Jamaal's voice: calm, never urgent or scolding.
public struct NotificationContent: Equatable, Sendable {
    public var title: String
    public var body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// The message layer for module 6: phrases what the planner decided (docs/architecture/rules-engine.md, "Modules emit
/// typed signals; a separate message-template layer phrases them").
public enum NotificationMessages {

    public static func content(for kind: NotificationKind) -> NotificationContent {
        switch kind {
        case .planningPrompt:
            return NotificationContent(title: "Tomorrow, gently", body: "A few quiet minutes to shape it, whenever you're ready.")
        case .morningNudge:
            return NotificationContent(title: "Good morning", body: "Here's today, in order. Open it when you're ready.")
        case .anchorStart(let title, let lead):
            return NotificationContent(title: title, body: lead <= 0 ? "Its window is open now." : "Opens in \(lead) min.")
        case .anchorClosing(let title, let minutes):
            return NotificationContent(title: title, body: "Closes in \(minutes) min.")
        case .habitReminder(let title):
            return NotificationContent(title: title, body: "A good moment for it, if you have one.")
        case .trialEnding(let day):
            switch day {
            case ..<14: return NotificationContent(title: "Your trial is nearly over", body: "Subscribe to keep shaping your days. Nothing is lost either way.")
            case 14: return NotificationContent(title: "Your trial ends tomorrow", body: "Subscribe to keep planning, or carry on read-only. Your record stays.")
            default: return NotificationContent(title: "Your trial has ended", body: "You can still live your day here. Subscribe whenever you'd like to plan again.")
            }
        }
    }
}

/// Where a tapped notification leads (docs: planning → Night Planning for the target date; Anchor or habit → Today;
/// trial → the subscription screen).
public enum NotificationRoute: Equatable, Sendable {
    case planning(CalendarDate)
    case today
    case subscription

    /// The route for a planned notification's stable id; anything unrecognised opens Today.
    public static func route(forID id: String) -> NotificationRoute {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard let prefix = parts.first else { return .today }
        switch prefix {
        case "planning":
            if parts.count == 2, let date = CalendarDate(isoString: parts[1]) { return .planning(date) }
            return .today
        case "trial": return .subscription
        default: return .today
        }
    }
}

/// What is scheduled with the system right now.
public struct PendingNotification: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var content: NotificationContent

    public init(id: String, fireDate: Date, content: NotificationContent) {
        self.id = id
        self.fireDate = fireDate
        self.content = content
    }
}

/// The difference between the plan and what is pending, so the app changes only what changed.
public enum NotificationDiff {
    public struct Changes: Equatable, Sendable {
        /// New or changed (a change replaces the pending one with the same id).
        public var add: [PlannedNotification]
        /// Pending ones the plan no longer wants: a habit logged, a night planned, a rule edited.
        public var remove: [String]
    }

    public static func make(planned: [PlannedNotification], pending: [PendingNotification]) -> Changes {
        let byID = Dictionary(pending.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let add = planned.filter { item in
            guard let existing = byID[item.id] else { return true }
            return abs(existing.fireDate.timeIntervalSince(item.fireDate)) >= 1 || existing.content != NotificationMessages.content(for: item.kind)
        }
        let wanted = Set(planned.map(\.id))
        let remove = pending.map(\.id).filter { !wanted.contains($0) }
        return Changes(add: add, remove: remove)
    }
}

/// The system's notification permission, as the app reads it on launch and every foreground.
public enum NotificationPermission: Equatable, Sendable {
    case notAsked
    case denied
    case granted
}

/// What denial (or a switched-off device) costs, and when to say so (docs G-76 … G-77).
public enum ReminderStatus {

    /// The lines on the warning card: what won't arrive. The planning prompt always; the morning list if it is on;
    /// then each Anchor rule that reminds, and the habits that have a reminder time.
    @MainActor
    public static func undelivered(in context: ModelContext, morningEnabled: Bool) throws -> [String] {
        var lines = ["The evening planning prompt"]
        if morningEnabled { lines.append("The morning list") }
        let rules = try context.fetch(FetchDescriptor<AnchorRule>())
            .filter { !$0.isArchived && reminds($0) }
            .sorted { ($0.createdAt, $0.title) < ($1.createdAt, $1.title) }
        for rule in rules { lines.append("\(rule.title) reminders") }
        let habits = try context.fetch(FetchDescriptor<Habit>())
            .filter { !$0.isArchived && ($0.windows ?? []).contains { $0.reminderMinute != nil } }
            .sorted { ($0.createdAt, $0.title) < ($1.createdAt, $1.title) }
            .map(\.title)
        if !habits.isEmpty { lines.append("\(list(habits)) reminders") }
        return lines
    }

    private static func reminds(_ rule: AnchorRule) -> Bool {
        switch rule.config {
        case .prayer(let config): config.reminder.map { $0.atStart || $0.beforeEndMinutes != nil } ?? false
        case .scheduled(let config): config.reminder.map { $0.atStart || $0.beforeEndMinutes != nil } ?? false
        case .needsAttention: false
        }
    }

    private static func list(_ items: [String]) -> String {
        items.count <= 2 ? items.joined(separator: " and ") : items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    /// Whether the Today banner shows: this device is meant to send reminders but the permission is off, it is past the
    /// planning time, tonight is neither planned nor skipped, and the user hasn't dismissed it today or said not to remind.
    public static func showsBanner(
        permission: NotificationPermission, remindersOnThisDevice: Bool, now: Date, boundary: DayBoundary,
        planningMinute: Int, tonightSettled: Bool, dismissedOn: CalendarDate?, dontRemind: Bool
    ) -> Bool {
        guard remindersOnThisDevice, permission != .granted, !dontRemind, !tonightSettled else { return false }
        let today = boundary.logicalDate(at: now)
        guard dismissedOn != today else { return false }
        return now >= boundary.instant(of: today, atMinute: planningMinute)
    }
}
