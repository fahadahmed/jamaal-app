//
//  ComingUpUITests.swift
//  JamaalUITests
//

import XCTest

/// Today's Coming up row and the Coming up screen (UP-01): tasks dated later wait there, off Today, and can be ticked.
final class ComingUpUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium", "-JamaalComingUp"]
        app.launch()
        return app
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
    }

    @MainActor
    func testFutureTasksStayOffTodayAndWaitInComingUp() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Draft the architecture review"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Groceries"].exists, "a task dated later is not on Today")
        let row = app.buttons["comingUpRow"]
        scrollTo(row, in: app)
        XCTAssertTrue(row.label.contains("next 14 days"), row.label)
        row.tap()
        XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tomorrow"].exists)
        XCTAssertTrue(app.staticTexts["Draft the migration estimate"].exists)
        XCTAssertTrue(app.staticTexts["Tasks wait here until you plan their day. Nothing counts toward capacity yet."].exists)
        app.buttons["comingUpBack"].tap()
        XCTAssertTrue(app.staticTexts["Draft the architecture review"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTickingAFutureTaskKeepsItListedSoItCanBeTakenBackAndTheRowCountDrops() throws {
        let app = launch()
        let row = app.buttons["comingUpRow"]
        XCTAssertTrue(app.staticTexts["Draft the architecture review"].waitForExistence(timeout: 10))
        scrollTo(row, in: app)
        func count() -> Int { Int(row.label.components(separatedBy: " ").compactMap { Int($0) }.first ?? -1) }
        let before = count()
        row.tap()
        let tick = app.buttons["Mark Groceries done"]
        XCTAssertTrue(tick.waitForExistence(timeout: 5))
        tick.tap()
        XCTAssertTrue(app.buttons["Mark Groceries not done"].waitForExistence(timeout: 5), "it stays, struck through, so the tick can be undone")
        app.buttons["comingUpBack"].tap()
        scrollTo(row, in: app)
        XCTAssertEqual(count(), before - 1)
    }
}
