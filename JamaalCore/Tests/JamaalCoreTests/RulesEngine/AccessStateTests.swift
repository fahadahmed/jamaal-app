import Foundation
import Testing
@testable import JamaalCore

/// The trial and the access state (docs/architecture/rules-engine.md, "Access and the trial"): a
/// 14-logical-day app-managed trial whose day 1 is the start day, then read-only unless entitled.
struct AccessStateTests {

    private func d(_ day: Int, month: Int = 10) -> CalendarDate { CalendarDate(year: 2026, month: month, day: day)! }

    // MARK: The start

    @Test func theTrialStartsOnTheEarlierOfTheDownloadDateAndFirstLaunch() {
        #expect(Trial.start(originalDownload: d(1), firstLaunch: d(5)) == d(1))
        #expect(Trial.start(originalDownload: d(5), firstLaunch: d(1)) == d(1))     // a reinstall never restarts it
        #expect(Trial.start(originalDownload: nil, firstLaunch: d(5)) == d(5))
        #expect(Trial.start(originalDownload: d(5), firstLaunch: nil) == d(5))
        #expect(Trial.start(originalDownload: nil, firstLaunch: nil) == nil)
    }

    // MARK: Days

    @Test(arguments: [(1, 1, 14), (2, 2, 13), (14, 14, 1)])
    func dayOneIsTheStartDayAndDaysLeftCountsLogicalDays(today: Int, number: Int, left: Int) {
        #expect(Trial.dayNumber(today: d(today), start: d(1)) == number)
        #expect(Trial.state(today: d(today), start: d(1), hasEntitlement: false) == .trial(daysLeft: left))
    }

    @Test func theTrialEndsAtTheRolloverAfterTheFourteenthDay() {
        #expect(Trial.state(today: d(14), start: d(1), hasEntitlement: false) == .trial(daysLeft: 1))
        #expect(Trial.state(today: d(15), start: d(1), hasEntitlement: false) == .readOnly)     // day 15
        #expect(Trial.state(today: d(30), start: d(1), hasEntitlement: false) == .readOnly)
    }

    @Test func anActiveEntitlementIsSubscribedAtAnyTimeAndLiftsReadOnly() {
        #expect(Trial.state(today: d(3), start: d(1), hasEntitlement: true) == .subscribed)      // subscribing early ends the trial's countdown
        #expect(Trial.state(today: d(30), start: d(1), hasEntitlement: true) == .subscribed)
    }

    @Test func withNoKnownStartTheTrialIsJustBeginning() {
        #expect(Trial.state(today: d(15), start: nil, hasEntitlement: false) == .trial(daysLeft: 14))
    }

    @Test func aStartInTheFutureCountsAsDayOne() {
        // A device clock behind the one that recorded the start: never a negative day.
        #expect(Trial.dayNumber(today: d(1), start: d(5)) == 1)
    }

    // MARK: Reminder dates

    @Test func trialEndRemindersFallOnDaysTwelveFourteenAndFifteen() {
        #expect(Trial.reminderDates(start: d(1)) == [d(12), d(14), d(15)])
        #expect(Trial.reminderDays == [12, 14, 15])
    }

    // MARK: What the state allows

    @Test func readOnlyLocksShapingThePlanButNotLivingTheDay() {
        #expect(AccessState.trial(daysLeft: 5).canShapeThePlan)
        #expect(AccessState.subscribed.canShapeThePlan)
        #expect(!AccessState.readOnly.canShapeThePlan)
        #expect(AccessState.readOnly.canLiveTheDay)                                             // ticking off, logging, timers, export
        #expect(AccessState.trial(daysLeft: 1).canLiveTheDay)
    }

    @Test func onlyReadOnlyShowsThePaywallAndOnlyUnsubscribedShowsTrialStatus() {
        #expect(AccessState.readOnly.showsPaywall)
        #expect(!AccessState.trial(daysLeft: 3).showsPaywall)
        #expect(!AccessState.subscribed.showsPaywall)
    }
}
