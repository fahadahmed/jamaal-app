import Foundation
import Testing
@testable import JamaalCore

/// The trial, the paywall and read-only (docs/journeys/walkthroughs/09-trial-paywall-read-only.md).
struct AccessPolicyTests {

    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }

    // MARK: Which actions

    @Test func livingTheDayIsAlwaysAllowed() {
        let living: [UserAction] = [.completeTask, .uncompleteTask, .logHabit, .correctRecentHabitDay, .addMinutesByHand, .markAnchor,
                                    .lateCorrectAnchor, .beginFocus, .finishFocus, .pickUpSession, .tickNoteChecklist, .undo,
                                    .changePreferences, .exportData]
        for action in living {
            #expect(!action.shapesThePlan, "\(action)")
            for access in [AccessState.trial(daysLeft: 5), .subscribed, .readOnly] { #expect(action.isAllowed(in: access), "\(action) \(access)") }
        }
    }

    @Test func shapingThePlanNeedsATrialOrASubscription() {
        let shaping = UserAction.allCases.filter(\.shapesThePlan)
        #expect(shaping.count == 20)
        for action in shaping {
            #expect(action.isAllowed(in: .trial(daysLeft: 1)), "\(action)")
            #expect(action.isAllowed(in: .subscribed), "\(action)")
            #expect(!action.isAllowed(in: .readOnly), "\(action)")
        }
        for action in [UserAction.createTask, .deferTask, .dropTask, .keepOrLater, .pauseHabit, .archiveOrRestore, .planTomorrow,
                       .moveOverload, .setCapacityLevel, .changeDaySettings, .createOneOffAnchor, .createCategory, .onboardingCreate] {
            #expect(action.shapesThePlan, "\(action)")
        }
    }

    @Test func everyActionIsOnOneSideOfTheLine() {
        #expect(UserAction.allCases.count == 14 + 20)
    }

    // MARK: The entitlement

    @Test func storeKitsAnswerWinsAndAFailedLookupNeverLocks() {
        #expect(EntitlementCache.isActive(confirmed: true, lastKnown: false))
        #expect(!EntitlementCache.isActive(confirmed: false, lastKnown: true))      // an expiry takes effect once StoreKit confirms it
        #expect(EntitlementCache.isActive(confirmed: nil, lastKnown: true))          // offline: as it last was
        #expect(!EntitlementCache.isActive(confirmed: nil, lastKnown: false))
        #expect(!EntitlementCache.isActive(confirmed: nil, lastKnown: nil))
    }

    // MARK: The paywall

    @Test func thePaywallShowsOncePerLogicalDayWhileReadOnlyAndNeverDuringFocus() {
        #expect(Paywall.shouldShow(access: .readOnly, lastShownOn: nil, today: d(15), focusRunning: false))
        #expect(Paywall.shouldShow(access: .readOnly, lastShownOn: d(14), today: d(15), focusRunning: false))
        #expect(!Paywall.shouldShow(access: .readOnly, lastShownOn: d(15), today: d(15), focusRunning: false))     // Not now is final for the day
        #expect(!Paywall.shouldShow(access: .readOnly, lastShownOn: nil, today: d(15), focusRunning: true))
        #expect(!Paywall.shouldShow(access: .subscribed, lastShownOn: nil, today: d(15), focusRunning: false))
        #expect(!Paywall.shouldShow(access: .trial(daysLeft: 1), lastShownOn: nil, today: d(15), focusRunning: false))
    }

    // MARK: The banner slot

    private func pick(_ access: AccessState, dismissed: CalendarDate? = nil, off: Bool = false) -> TodayBanner? {
        TodayBanner.pick(access: access, trialBannerDismissedOn: dismissed, today: d(15), notificationsOffBanner: off)
    }

    @Test func theMostPressingBannerHoldsTheSlot() {
        #expect(pick(.readOnly, off: true) == .readOnly)                                 // read-only beats notifications-off
        #expect(pick(.trial(daysLeft: 3), off: true) == .trialEnding(daysLeft: 3))
        #expect(pick(.trial(daysLeft: 1)) == .trialEnding(daysLeft: 1))
        #expect(pick(.trial(daysLeft: 4), off: true) == .notificationsOff)               // too early for the trial banner
        #expect(pick(.trial(daysLeft: 9)) == nil)
        #expect(pick(.subscribed, off: true) == .notificationsOff)
        #expect(pick(.subscribed) == nil)
    }

    @Test func aDismissedTrialBannerStaysAwayForTheDayAndLetsTheNextOneIn() {
        #expect(pick(.trial(daysLeft: 2), dismissed: d(15)) == nil)
        #expect(pick(.trial(daysLeft: 2), dismissed: d(15), off: true) == .notificationsOff)
        #expect(pick(.trial(daysLeft: 2), dismissed: d(14)) == .trialEnding(daysLeft: 2))      // yesterday's dismissal is over
        #expect(pick(.readOnly, dismissed: d(15)) == .readOnly)                                   // read-only can't be dismissed
    }
}
