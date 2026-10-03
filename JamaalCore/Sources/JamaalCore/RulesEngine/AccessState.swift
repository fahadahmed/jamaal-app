import Foundation

/// Whether the user is in the trial, subscribed, or read-only (docs/architecture/rules-engine.md,
/// "Access and the trial"). A pure function of the trial dates and the entitlement; StoreKit supplies
/// the entitlement (an active one, including a billing grace period or retry, so a failed card never
/// locks anyone out) at the app layer.
public enum AccessState: Equatable, Sendable {
    /// The app-managed trial, with logical days left (1 on the last day).
    case trial(daysLeft: Int)
    case subscribed
    /// The trial has ended and there is no entitlement: living the day works, shaping the plan is locked.
    case readOnly

    /// Creating or editing, manual Defer and Drop, Night Planning and the capacity settings.
    public var canShapeThePlan: Bool { self != .readOnly }

    /// Ticking off, logging, Anchor outcomes, focus timers, undo, export: always, so the day isn't held hostage.
    public var canLiveTheDay: Bool { true }

    /// The calm paywall appears only once the trial has ended unsubscribed.
    public var showsPaywall: Bool { self == .readOnly }
}

/// The 14-logical-day trial: no payment up front, day 1 is the start day, and it ends at the rollover
/// after the 14th day.
public enum Trial {
    public static let lengthDays = 14
    /// The trial days on which a quiet reminder is sent: two before the end, and the first read-only day.
    public static let reminderDays = [12, 14, 15]

    /// The earlier of StoreKit's original-download date and the synced `firstLaunchAt`, so a reinstall
    /// or a second device never restarts the trial.
    public static func start(originalDownload: CalendarDate?, firstLaunch: CalendarDate?) -> CalendarDate? {
        switch (originalDownload, firstLaunch) {
        case (let a?, let b?): min(a, b)
        case (let a?, nil): a
        case (nil, let b?): b
        case (nil, nil): nil
        }
    }

    /// 1 on the start day. A start in the future (a clock set back) is day 1, never negative.
    public static func dayNumber(today: CalendarDate, start: CalendarDate) -> Int {
        max(1, start.days(until: today) + 1)
    }

    /// An entitlement is `subscribed` at any time; otherwise the trial runs for 14 days, then read-only.
    /// With no known start the trial is just beginning.
    public static func state(today: CalendarDate, start: CalendarDate?, hasEntitlement: Bool) -> AccessState {
        if hasEntitlement { return .subscribed }
        guard let start else { return .trial(daysLeft: lengthDays) }
        let day = dayNumber(today: today, start: start)
        return day <= lengthDays ? .trial(daysLeft: lengthDays - day + 1) : .readOnly
    }

    /// The dates of the reminders: days 12, 14 and 15 of the trial.
    public static func reminderDates(start: CalendarDate) -> [CalendarDate] {
        reminderDays.map { start.addingDays($0 - 1) }
    }
}
