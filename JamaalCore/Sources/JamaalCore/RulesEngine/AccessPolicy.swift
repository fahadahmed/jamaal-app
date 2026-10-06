import Foundation

/// What a person can do in the app, sorted by whether it lives the day or shapes the plan
/// (docs/journeys/walkthroughs/09-trial-paywall-read-only.md, G-70).
public enum UserAction: CaseIterable, Sendable {
    // Living the day: always allowed, so the day isn't held hostage.
    case completeTask, uncompleteTask
    case logHabit, correctRecentHabitDay, addMinutesByHand
    case markAnchor, lateCorrectAnchor
    case beginFocus, finishFocus, pickUpSession, tickNoteChecklist
    case undo, changePreferences, exportData
    // Shaping the plan: needs a subscription once the trial has ended.
    case createTask, editTask, deferTask, dropTask, keepOrLater
    case createHabit, editHabit, pauseHabit, archiveOrRestore
    case createAnchorRule, editAnchorRule, createOneOffAnchor
    case createCategory, editCategory
    case planTomorrow, morningCard, moveOverload
    case setCapacityLevel, changeDaySettings
    case onboardingCreate

    /// Whether this action shapes the plan (so read-only locks it).
    public var shapesThePlan: Bool {
        switch self {
        case .completeTask, .uncompleteTask, .logHabit, .correctRecentHabitDay, .addMinutesByHand, .markAnchor, .lateCorrectAnchor,
             .beginFocus, .finishFocus, .pickUpSession, .tickNoteChecklist, .undo, .changePreferences, .exportData:
            false
        default:
            true
        }
    }

    public func isAllowed(in access: AccessState) -> Bool { shapesThePlan ? access.canShapeThePlan : access.canLiveTheDay }
}

/// The entitlement the app trusts (docs G-68): StoreKit's answer when it gives one, otherwise the last answer, so being
/// offline or a failed lookup never locks anyone out.
public enum EntitlementCache {

    /// - Parameters:
    ///   - confirmed: what StoreKit says now (`true` active, `false` none or expired), or `nil` when it couldn't be reached.
    ///   - lastKnown: the last confirmed answer kept on this device, or `nil` if there never was one.
    public static func isActive(confirmed: Bool?, lastKnown: Bool?) -> Bool {
        confirmed ?? lastKnown ?? false
    }
}

/// The calm full-screen paywall (SB-01): once on the first open of each logical day while read-only, never during a
/// focus session, and *Not now* is final for the day.
public enum Paywall {
    public static func shouldShow(access: AccessState, lastShownOn: CalendarDate?, today: CalendarDate, focusRunning: Bool) -> Bool {
        access.showsPaywall && lastShownOn != today && !focusRunning
    }
}

/// What holds the slim slot at the top of Today, one at a time, most pressing first (SB-03, TD-05).
public enum TodayBanner: Equatable, Sendable {
    case readOnly
    case trialEnding(daysLeft: Int)
    case notificationsOff

    /// The trial banner starts three days before the trial ends.
    public static let trialWarningDays = 3

    public static func pick(
        access: AccessState, trialBannerDismissedOn: CalendarDate?, today: CalendarDate, notificationsOffBanner: Bool
    ) -> TodayBanner? {
        switch access {
        case .readOnly:
            return .readOnly
        case .trial(let daysLeft) where daysLeft <= trialWarningDays && trialBannerDismissedOn != today:
            return .trialEnding(daysLeft: daysLeft)
        default:
            return notificationsOffBanner ? .notificationsOff : nil
        }
    }
}
