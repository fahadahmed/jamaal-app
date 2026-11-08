//
//  DayReviewUITests.swift
//  JamaalUITests
//

import XCTest

/// Today's Yesterday row and Day review (DY-01): a closed day, read-only, with arrows to the days either side.
final class DayReviewUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalPastDays", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"]
        app.launch()
        return app
    }

    @MainActor
    private func openYesterday(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Draft the architecture review"].waitForExistence(timeout: 10))
        let row = app.buttons["yesterdayRow"]
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.label.hasPrefix("Yesterday · 1 of"), row.label)
        row.tap()
        XCTAssertTrue(app.buttons["dayReviewBack"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testYesterdayShowsWhatWasDoneDeferredAndCarried() throws {
        let app = launch()
        openYesterday(app)
        XCTAssertTrue(app.staticTexts["Send the invoice"].exists)
        XCTAssertTrue(app.staticTexts["Plan the weekend"].exists)
        XCTAssertTrue(app.staticTexts["Renew the library card"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Deferred to'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Not done · carried to'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Past days are read-only. A missed task can be ticked for two days."].exists)
        XCTAssertFalse(app.buttons["dayReviewNext"].isEnabled, "next stops at yesterday")
    }

    @MainActor
    func testTheArrowsWalkBackToTheFirstDayAndStopThere() throws {
        let app = launch()
        openYesterday(app)
        let date = app.staticTexts["dayReviewDate"]
        let yesterdayLabel = date.label
        app.buttons["dayReviewPrevious"].tap()
        XCTAssertNotEqual(date.label, yesterdayLabel)
        XCTAssertTrue(app.staticTexts["Book the dentist"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dayReviewNext"].isEnabled)
        // Back as far as it goes: the first day with any data (the sample habits are older than the sample tasks).
        var steps = 0
        while app.buttons["dayReviewPrevious"].isEnabled && steps < 200 { app.buttons["dayReviewPrevious"].tap(); steps += 1 }
        XCTAssertFalse(app.buttons["dayReviewPrevious"].isEnabled, "it stops at the first day")
        XCTAssertTrue(steps >= 2 && steps < 200, "it did go back (\(steps) days)")
        XCTAssertTrue(app.buttons["dayReviewNext"].isEnabled)
        app.buttons["dayReviewNext"].tap()
        XCTAssertNotEqual(date.label, yesterdayLabel)
    }

    @MainActor
    func testMarkingAMissedTaskDoneInsideTheWindowCountsItOnThatDay() throws {
        let app = launch()
        openYesterday(app)
        let mark = app.buttons["dayReviewMarkDone-Renew the library card"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.tap()
        XCTAssertFalse(mark.waitForExistence(timeout: 2) && mark.exists, "the button goes once it is done")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Done '")).count >= 2)
        app.buttons["dayReviewBack"].tap()
        XCTAssertTrue(app.buttons["yesterdayRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["yesterdayRow"].label.hasPrefix("Yesterday · 2 of"), app.buttons["yesterdayRow"].label)
    }
}
