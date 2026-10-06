//
//  SubscriptionUITests.swift
//  JamaalUITests
//

import XCTest

/// The trial, the paywall and the Subscription screen, with the access state forced and a fake store.
final class SubscriptionUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ access: String?, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"] + (access.map { ["-JamaalAccess", $0] } ?? []) + extra
        app.launch()
        return app
    }

    @MainActor
    private func openSubscription(_ app: XCUIApplication) {
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let row = app.buttons["settings-subscription"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    // MARK: The paywall

    @MainActor
    func testWhenTheTrialHasEndedThePaywallShowsOnceAndNotNowLeavesAReadOnlyBanner() throws {
        let app = launch("readOnly")
        let subscribe = app.buttons["subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["THE TRIAL HAS ENDED"].exists)
        XCTAssertTrue(app.staticTexts["Keep shaping your days."].exists)
        XCTAssertEqual(subscribe.label, "Subscribe yearly")
        XCTAssertTrue(app.buttons["plan-yearly"].exists && app.buttons["plan-monthly"].exists)
        app.buttons["notNow"].tap()
        let banner = app.descendants(matching: .any)["readOnlyBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'The trial has ended. You can still tick things off'")).firstMatch.exists)
        XCTAssertFalse(app.buttons["subscribe"].exists)                         // once a day, and Not now is final for it
    }

    @MainActor
    func testTheBannerSubscribeOpensThePlansAndChoosingMonthlyChangesTheButton() throws {
        let app = launch("readOnly")
        XCTAssertTrue(app.buttons["notNow"].waitForExistence(timeout: 10))
        app.buttons["notNow"].tap()
        let action = app.buttons["readOnlyBannerAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()
        XCTAssertTrue(app.buttons["plan-monthly"].waitForExistence(timeout: 5))
        app.buttons["plan-monthly"].tap()
        XCTAssertEqual(app.buttons["subscribe"].label, "Subscribe monthly")
    }

    @MainActor
    func testSubscribingLiftsTheLocksAndTheBannerGoes() throws {
        let app = launch("readOnly")
        let subscribe = app.buttons["subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10))
        subscribe.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["readOnlyBanner"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["subscribe"].exists)
    }

    // MARK: The trial

    @MainActor
    func testTwoDaysLeftShowsTheTrialBannerAndItCanBeDismissedForTheDay() throws {
        let app = launch("trial:2")
        let banner = app.descendants(matching: .any)["trialBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Two days left in the trial.'")).firstMatch.exists)
        XCTAssertFalse(app.buttons["subscribe"].exists)                        // the paywall waits until the trial has ended
        app.buttons["trialBannerDismiss"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: banner)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    func testNineDaysLeftSaysNothingOnToday() throws {
        let app = launch("trial:9")
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["trialBanner"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["readOnlyBanner"].exists)
    }

    // MARK: Settings

    @MainActor
    func testTheSubscriptionScreenSaysWhereTheTrialStands() throws {
        let app = launch("trial:9")
        let row = { () -> XCUIElement in
            app.tabBars.buttons["Settings"].tap()
            return app.buttons["settings-subscription"]
        }()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Trial · 9 days left"), row.label)
        row.tap()
        XCTAssertEqual(app.staticTexts["subscriptionLabel"].label, "FREE TRIAL")
        XCTAssertTrue(app.staticTexts["subscriptionLine"].label.hasPrefix("9 days left."))
        XCTAssertTrue(app.buttons["seePlans"].exists && app.buttons["restorePurchases"].exists && app.buttons["manageSubscription"].exists)
    }

    @MainActor
    func testSeePlansOpensThePlansAndRestoreWithNothingToRestoreSaysSoCalmly() throws {
        let app = launch("trial:9")
        openSubscription(app)
        app.buttons["restorePurchases"].tap()
        XCTAssertTrue(app.staticTexts["subscriptionMessage"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["subscriptionMessage"].label, "No earlier purchase was found for this Apple ID.")
        app.buttons["seePlans"].tap()
        XCTAssertTrue(app.buttons["plan-yearly"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["SUBSCRIBE"].exists, true)
    }

    @MainActor
    func testSubscribedShowsThankYouAndNoPlans() throws {
        let app = launch("subscribed")
        openSubscription(app)
        XCTAssertEqual(app.staticTexts["subscriptionLabel"].waitForExistence(timeout: 5) ? app.staticTexts["subscriptionLabel"].label : "", "SUBSCRIBED")
        XCTAssertFalse(app.buttons["seePlans"].exists)
        XCTAssertTrue(app.staticTexts["subscriptionLine"].label.contains("Thank you."))
    }
}
