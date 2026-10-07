//
//  PlanningGapsUITests.swift
//  JamaalUITests
//

import XCTest

/// Night Planning's Build step (a task or a one-off Anchor) and the normal-day line on the Load step.
final class PlanningGapsUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(step: Int, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalPlan", String(step)] + extra
        app.launch()
        return app
    }

    // MARK: Build

    @MainActor
    func testBuildOffersATaskOrAOneOffAnchorForTomorrow() throws {
        let app = launch(step: 3)
        let add = app.buttons["buildAddTask"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertEqual(add.label, "Add a task or Anchor")
        add.tap()
        let mode = app.segmentedControls["addMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.buttons["Anchor"].tap()
        let title = app.textFields["oneOffTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Dentist\n")
        let save = app.buttons["addTaskButton"]
        XCTAssertEqual(save.label, "Add Anchor for tomorrow")                          // the planned day, not today
        save.tap()
        let appears = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Dentist'")).firstMatch
        XCTAssertTrue(appears.waitForExistence(timeout: 8), "tomorrow's timeline shows the Anchor once it is made")
    }

    // MARK: Load

    @MainActor
    func testLoadOffersTheNormalDayLineAndSetItChangesTheBudgets() throws {
        let app = launch(step: 4, extra: ["-JamaalNormalDayHistory"])
        let offer = app.staticTexts["normalDayOffer"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10))
        XCTAssertEqual(offer.label, "You usually do about 2h 45m — set your normal day to that?")
        app.buttons["setNormalDay"].tap()
        XCTAssertFalse(offer.waitForExistence(timeout: 2))
        app.buttons["planSkip"].tap()                                                         // leave planning; the setting stays
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings-capacity"].tap()
        XCTAssertEqual(app.staticTexts["normalDay"].label, "2h 45m")
    }

    @MainActor
    func testNotNowPutsTheLineAway() throws {
        let app = launch(step: 4, extra: ["-JamaalNormalDayHistory"])
        XCTAssertTrue(app.staticTexts["normalDayOffer"].waitForExistence(timeout: 10))
        app.buttons["declineNormalDay"].tap()
        XCTAssertFalse(app.staticTexts["normalDayOffer"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testItIsOfferedAtMostOnceInNightPlanning() throws {
        let app = launch(step: 4, extra: ["-JamaalNormalDayHistory"])
        XCTAssertTrue(app.staticTexts["normalDayOffer"].waitForExistence(timeout: 10))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["3 OF 5 · BUILD"].waitForExistence(timeout: 5))
        app.buttons["planContinue"].tap()
        XCTAssertTrue(app.staticTexts["4 OF 5 · LOAD"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["normalDayOffer"].waitForExistence(timeout: 3))        // already seen once: not again
    }

    @MainActor
    func testThereIsNoLineWithoutAFortnightOfUse() throws {
        let app = launch(step: 4)
        XCTAssertTrue(app.staticTexts["4 OF 5 · LOAD"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["normalDayOffer"].waitForExistence(timeout: 2))
    }
}
