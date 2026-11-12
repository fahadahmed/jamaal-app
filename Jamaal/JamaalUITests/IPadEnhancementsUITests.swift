//
//  IPadEnhancementsUITests.swift
//  JamaalUITests
//

import XCTest

/// The v1 enhancements on a wide layout: Day review takes the detail column, Coming up takes the list column and opens a task in the
/// detail column, and a field's picker is a popover on its row. Runs on an iPad simulator; skips on a phone.
final class IPadEnhancementsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "regular width only")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalPastDays", "-JamaalComingUp", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        return app
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    @MainActor
    func testYesterdayOpensDayReviewInTheDetailColumnWhileTheListStaysPut() throws {
        let app = launch()
        let row = app.buttons["yesterdayRow"]
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 10))
        scrollTo(row, in: app)
        row.tap()
        let date = app.staticTexts["dayReviewDate"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        let panel = app.descendants(matching: .any)["detailPanel"]
        XCTAssertGreaterThanOrEqual(date.frame.minX, panel.frame.minX, "Day review is in the detail column")
        XCTAssertFalse(app.buttons["dayReviewBack"].exists, "there is no back button: the list stays where it is")
        XCTAssertTrue(row.exists, "and the Yesterday row is still in the list")
        XCTAssertTrue(app.staticTexts["Send the invoice"].exists)
        // Picking a task replaces it.
        let clinic = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Draft the architecture review'")).firstMatch
        scrollTo(clinic, in: app)
        clinic.tap()
        XCTAssertTrue(app.buttons["detailRow-Effort"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["dayReviewDate"].exists)
    }

    @MainActor
    func testComingUpTakesTheListColumnAndAFutureTaskOpensInTheDetailColumn() throws {
        let app = launch()
        let row = app.buttons["comingUpRow"]
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 10))
        scrollTo(row, in: app)
        row.tap()
        let groceries = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Groceries'")).firstMatch
        XCTAssertTrue(groceries.waitForExistence(timeout: 5))
        let panel = app.descendants(matching: .any)["detailPanel"]
        XCTAssertLessThanOrEqual(groceries.frame.maxX, panel.frame.minX + 1, "Coming up is in the list column")
        groceries.tap()
        XCTAssertTrue(app.buttons["moveToToday"].waitForExistence(timeout: 5), "the task opened in the detail column, not a sheet")
        XCTAssertGreaterThanOrEqual(app.buttons["moveToToday"].frame.minX, panel.frame.minX)
        XCTAssertTrue(groceries.exists, "and Coming up is still showing beside it")
    }

    @MainActor
    func testAFieldsPickerIsAPopoverOnItsRowNotAPush() throws {
        let app = launch()
        let task = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Call the clinic back'")).firstMatch
        scrollTo(task, in: app)
        task.tap()
        let effort = app.buttons["detailRow-Effort"]
        XCTAssertTrue(effort.waitForExistence(timeout: 5))
        effort.tap()
        XCTAssertTrue(app.buttons["effort-45"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pickerBack"].exists, "a popover has no back button")
        app.buttons["effort-45"].tap()
        XCTAssertTrue(app.buttons["detailRow-Effort"].waitForExistence(timeout: 5))
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '45 min'"), object: app.buttons["detailRow-Effort"])
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 8), .completed)
    }
}
