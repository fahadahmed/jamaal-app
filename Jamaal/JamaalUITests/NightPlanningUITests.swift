//
//  NightPlanningUITests.swift
//  JamaalUITests
//

import XCTest

/// Night Planning end to end: the five steps, Skip tonight, leaving and resuming, and what Keep and Drop do.
final class NightPlanningUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        return app
    }

    @MainActor
    private func open(_ app: XCUIApplication) {
        let moon = app.buttons["planTomorrow"]
        XCTAssertTrue(moon.waitForExistence(timeout: 10))
        moon.tap()
        XCTAssertTrue(app.staticTexts["1 OF 5 · REVIEW"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func cont(_ app: XCUIApplication) {
        let button = app.buttons["planContinue"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    @MainActor
    func testTheWholeFlowRunsFromReviewToGoodNight() throws {
        let app = launch()
        open(app)
        cont(app)
        XCTAssertTrue(app.staticTexts["2 OF 5 · CARRY"].waitForExistence(timeout: 5))
        cont(app)
        XCTAssertTrue(app.staticTexts["3 OF 5 · BUILD"].waitForExistence(timeout: 5))
        cont(app)
        XCTAssertTrue(app.staticTexts["4 OF 5 · LOAD"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["Capacity for today"].exists)
        cont(app)
        XCTAssertTrue(app.staticTexts["Tomorrow is ready."].waitForExistence(timeout: 5))
        app.buttons["goodNight"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSkipTonightLeavesAtAnyStepWithoutAFuss() throws {
        let app = launch()
        open(app)
        cont(app)
        XCTAssertTrue(app.staticTexts["2 OF 5 · CARRY"].waitForExistence(timeout: 5))
        app.buttons["planSkip"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["2 OF 5 · CARRY"].exists)
    }

    @MainActor
    func testLeavingMidFlowResumesAtTheSameStep() throws {
        let app = launch()
        open(app)
        cont(app)
        XCTAssertTrue(app.staticTexts["2 OF 5 · CARRY"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        app.buttons["planTomorrow"].tap()
        XCTAssertTrue(app.staticTexts["2 OF 5 · CARRY"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBackReturnsToTheStepBefore() throws {
        let app = launch()
        open(app)
        cont(app)
        cont(app)
        XCTAssertTrue(app.staticTexts["3 OF 5 · BUILD"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["2 OF 5 · CARRY"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testKeepingAndDroppingInCarryChangeTodaysList() throws {
        let app = launch()
        open(app)
        cont(app)
        XCTAssertTrue(app.staticTexts["2 OF 5 · CARRY"].waitForExistence(timeout: 5))
        // Drop one, leave the rest to be kept for tomorrow on Continue.
        app.buttons["drop-Book Yusuf's swimming lessons"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        cont(app)
        XCTAssertTrue(app.staticTexts["3 OF 5 · BUILD"].waitForExistence(timeout: 5))
        // Keep moved the others to tomorrow, so they appear among tomorrow's tasks. (The clinic call is on its
        // third deferral, so it goes to next week instead and is not among them.)
        XCTAssertTrue(app.staticTexts["Draft the architecture review"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Call the clinic back"].exists)
    }

    @MainActor
    func testDroppingCanBeUndoneBeforeTheDayIsClosed() throws {
        let app = launch()
        open(app)
        cont(app)
        app.buttons["drop-Book Yusuf's swimming lessons"].tap()
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Undo"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    func testAnEmptyDayStillPlansTomorrowWithoutAFuss() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"]
        app.launch()
        open(app)
        cont(app)                                              // nothing to carry: straight to Build
        XCTAssertTrue(app.staticTexts["2 OF 4 · BUILD"].waitForExistence(timeout: 5) || app.staticTexts["3 OF 5 · BUILD"].waitForExistence(timeout: 5))
    }
}
