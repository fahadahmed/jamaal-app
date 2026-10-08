//
//  ReadOnlyUITests.swift
//  JamaalUITests
//

import XCTest

/// After the trial: living the day still works, shaping the plan opens one calm sheet, and nothing is hidden or half done.
final class ReadOnlyUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    /// Read-only, past the day's paywall.
    @MainActor
    private func launchReadOnly(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalAccess", "readOnly"] + extra
        app.launch()
        let notNow = app.buttons["notNow"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 10))
        notNow.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func sheet(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["lockedSheet"] }

    @MainActor
    private func assertLocked(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(sheet(app).waitForExistence(timeout: 5), "the locked sheet should open", file: file, line: line)
        XCTAssertTrue(app.staticTexts["Adding and planning need a subscription"].exists, file: file, line: line)
        XCTAssertTrue(app.staticTexts["Everything already here keeps working for the day."].exists, file: file, line: line)
    }

    @MainActor
    private func dismissSheet(_ app: XCUIApplication) {
        app.buttons["lockedNotNow"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet(app))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    // MARK: Today

    @MainActor
    func testAddingATaskOpensTheCalmSheetNotTheAddSheet() throws {
        let app = launchReadOnly()
        app.buttons["addButton"].tap()
        assertLocked(app)
        XCTAssertFalse(app.buttons["addTaskButton"].exists)                      // the Add sheet never opened
        dismissSheet(app)
        XCTAssertTrue(app.buttons["addButton"].exists)                           // and the Add button is still there
    }

    @MainActor
    func testLivingTheDayStillWorks() throws {
        let app = launchReadOnly()
        let tick = app.buttons["Mark Draft the architecture review done"]
        XCTAssertTrue(tick.waitForExistence(timeout: 10))
        tick.tap()
        XCTAssertTrue(app.buttons["Mark Draft the architecture review not done"].waitForExistence(timeout: 5))
        XCTAssertFalse(sheet(app).exists)
    }

    @MainActor
    func testPlanTomorrowIsHiddenSinceThereIsNothingToExplain() throws {
        let app = launchReadOnly()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["planTomorrow"].exists)
    }

    @MainActor
    func testTheCapacitySliderIsLockedToo() throws {
        let app = launchReadOnly()
        let slider = app.sliders["Capacity for today"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.2)).tap()
        assertLocked(app)
        dismissSheet(app)
        XCTAssertEqual(slider.value as? String, "Medium")                        // unchanged
    }

    @MainActor
    private func openClinicTask(_ app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Call the clinic back'")).firstMatch
        for _ in 0..<5 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    @MainActor
    func testDeferOnATaskIsLockedButBeginIsNot() throws {
        let app = launchReadOnly()
        openClinicTask(app)
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 10))      // starting a timer is living the day
        app.buttons["deferButton"].tap()
        assertLocked(app)
        dismissSheet(app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDropOnATaskIsLocked() throws {
        let app = launchReadOnly()
        openClinicTask(app)
        let drop = app.buttons["dropButton"]
        XCTAssertTrue(drop.waitForExistence(timeout: 10))
        drop.tap()
        assertLocked(app)
    }

    // MARK: Habits and Anchors

    @MainActor
    func testAddingAHabitAndAnAnchorRuleAreLocked() throws {
        let app = launchReadOnly()
        app.tabBars.buttons["Habits"].tap()
        let add = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        assertLocked(app)
        dismissSheet(app)
        app.buttons["segment-anchors"].tap()
        let addRule = app.buttons["addAnchorRule"]
        XCTAssertTrue(addRule.waitForExistence(timeout: 5))
        addRule.tap()
        assertLocked(app)
    }

    // MARK: Settings

    @MainActor
    func testTheDaySettingsAndCategoriesAreLockedAndKeepTheirValues() throws {
        let app = launchReadOnly()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings-capacity"].tap()
        let more = app.buttons["Add one to normal day"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        assertLocked(app)
        dismissSheet(app)
        XCTAssertEqual(app.staticTexts["normalDay"].label, "3h")                 // unchanged
        app.buttons["Back"].tap()
        app.buttons["settings-categories"].tap()
        let addCategory = app.buttons["addCategory"]
        XCTAssertTrue(addCategory.waitForExistence(timeout: 5))
        addCategory.tap()
        assertLocked(app)
    }

    @MainActor
    func testNotificationPreferencesStayOpenToAnyone() throws {
        let app = launchReadOnly(["-JamaalFakeNotifications", "granted"])
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings-notifications"].tap()
        let toggle = app.switches["remindersSwitch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertFalse(sheet(app).exists)                                        // preferences are not shaping the plan
    }

    // MARK: Subscribing from the sheet

    @MainActor
    func testSubscribeOnTheSheetOpensThePlansAndBuyingLiftsEveryLock() throws {
        let app = launchReadOnly()
        app.buttons["addButton"].tap()
        assertLocked(app)
        app.buttons["lockedSubscribe"].tap()
        let subscribe = app.buttons["subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10))
        subscribe.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        app.buttons["addButton"].tap()
        XCTAssertTrue(app.buttons["addTaskButton"].waitForExistence(timeout: 5))   // the Add sheet opens now
        XCTAssertFalse(sheet(app).exists)
    }

    // MARK: Not read-only

    @MainActor
    func testDuringTheTrialNothingIsLocked() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalAccess", "trial:9"]
        app.launch()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        app.buttons["addButton"].tap()
        XCTAssertTrue(app.buttons["addTaskButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(sheet(app).exists)
    }
}
