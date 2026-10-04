//
//  MorningPlanningUITests.swift
//  JamaalUITests
//

import XCTest

/// The ways into Night Planning that Today offers on its own: the morning card with its shortened flow, and the
/// quiet evening row. (The debug arguments pretend it is 09:00 or 21:00.)
final class MorningPlanningUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testTheMorningCardOffersAPlanAndTheShortenedFlowRunsToTodayIsSet() throws {
        let app = launch(["-JamaalMorning"])
        XCTAssertTrue(app.otherElements["morningCard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No plan for today — two minutes to pick?"].exists)
        app.buttons["pickForToday"].tap()

        XCTAssertTrue(app.staticTexts["THIS MORNING · 1 OF 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["planSkip"].label == "Not now")
        app.buttons["planContinue"].tap()
        XCTAssertTrue(app.staticTexts["THIS MORNING · 2 OF 3"].waitForExistence(timeout: 5))
        app.buttons["planContinue"].tap()
        XCTAssertTrue(app.staticTexts["Today is set."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["goodNight"].label == "Open Today")
        app.buttons["goodNight"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["morningCard"].exists)
    }

    @MainActor
    func testNotNowPutsTheCardAway() throws {
        let app = launch(["-JamaalMorning"])
        XCTAssertTrue(app.otherElements["morningCard"].waitForExistence(timeout: 10))
        app.buttons["morningNotNow"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.otherElements["morningCard"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    func testTheCardIsOffWhenNothingAsksForIt() throws {
        let app = launch([])
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["morningCard"].exists)
        XCTAssertFalse(app.buttons["planTomorrowRow"].exists)
    }

    @MainActor
    func testTheEveningRowAppearsAfterThePlanningTimeAndOpensThePlan() throws {
        let app = launch(["-JamaalEvening"])
        let row = app.buttons["planTomorrowRow"]
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.staticTexts["1 OF 5 · REVIEW"].waitForExistence(timeout: 5))
    }
}
