//
//  NotificationsUITests.swift
//  JamaalUITests
//

import XCTest

/// Reminders: the Notifications and times screen in each permission state, and the Today banner.
final class NotificationsUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ permission: String, extra: [String] = [], tab: String? = "Settings") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalFakeNotifications", permission] + extra
        app.launch()
        if let tab {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
        }
        return app
    }

    @MainActor
    private func openNotifications(_ app: XCUIApplication) {
        let row = app.buttons["settings-notifications"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    @MainActor
    func testDeniedShowsTheWarningCardWithWhatWontArriveAndTheHomeRowSaysSo() throws {
        let app = launch("denied")
        let row = app.buttons["settings-notifications"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Off in Settings"), row.label)
        row.tap()
        let card = app.descendants(matching: .any)["warningCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["· The evening planning prompt"].exists)
        XCTAssertTrue(app.staticTexts["· The morning list"].exists)
        XCTAssertTrue(app.buttons["warningButton"].label.hasPrefix("Open"))
        XCTAssertEqual(app.staticTexts["debugScheduled"].label, "scheduled 0")
    }

    @MainActor
    func testNotAskedCanBeTurnedOnInContextAndThenSchedules() throws {
        let app = launch("notAsked")
        openNotifications(app)
        let button = app.buttons["warningButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertEqual(button.label, "Turn on reminders")
        button.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.descendants(matching: .any)["warningCard"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed)
        let scheduled = NSPredicate(format: "label != 'scheduled 0'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: scheduled, object: app.staticTexts["debugScheduled"])], timeout: 8), .completed)
    }

    @MainActor
    func testGrantedShowsNoCardAndTheSwitchStopsEverything() throws {
        let app = launch("granted")
        openNotifications(app)
        let toggle = app.switches["remindersSwitch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["warningCard"].exists)
        let scheduled = NSPredicate(format: "label != 'scheduled 0'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: scheduled, object: app.staticTexts["debugScheduled"])], timeout: 8), .completed)
        toggle.tap()
        let none = NSPredicate(format: "label == 'scheduled 0'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: none, object: app.staticTexts["debugScheduled"])], timeout: 8), .completed)
        XCTAssertFalse(app.descendants(matching: .any)["warningCard"].exists)        // quiet by choice: nothing is said
    }

    @MainActor
    func testTheMorningListCanBeSwitchedOffAndItsTimeHides() throws {
        let app = launch("granted")
        openNotifications(app)
        let morning = app.switches["morningSwitch"]
        XCTAssertTrue(morning.waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["morningTime"].exists || app.otherElements["morningTime"].exists || app.buttons["morningTime"].exists)
        morning.tap()
        XCTAssertFalse(app.datePickers["morningTime"].exists)
    }

    @MainActor
    func testTheTodayBannerAppearsInTheEveningWhenRemindersAreOffAndIsDismissedForTheDay() throws {
        let app = launch("denied", extra: ["-JamaalEvening"], tab: nil)
        let banner = app.descendants(matching: .any)["remindersBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        app.buttons["bannerNotToday"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: banner)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    func testNoBannerWhenRemindersAreOnOrItIsNotYetEvening() throws {
        let granted = launch("granted", extra: ["-JamaalEvening"], tab: nil)
        XCTAssertTrue(granted.buttons["planTomorrowRow"].waitForExistence(timeout: 10))
        XCTAssertFalse(granted.descendants(matching: .any)["remindersBanner"].exists)
        granted.terminate()
        let daytime = launch("denied", tab: nil)
        XCTAssertTrue(daytime.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(daytime.descendants(matching: .any)["remindersBanner"].exists)
    }

    @MainActor
    func testTheBannerStartsEveningPlanning() throws {
        let app = launch("denied", extra: ["-JamaalEvening"], tab: nil)
        let plan = app.buttons["bannerPlan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        plan.tap()
        XCTAssertTrue(app.buttons["Skip tonight"].waitForExistence(timeout: 10) || app.staticTexts["Review"].waitForExistence(timeout: 5))
    }
}
