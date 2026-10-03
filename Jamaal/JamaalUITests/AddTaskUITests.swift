//
//  AddTaskUITests.swift
//  JamaalUITests
//

import XCTest

/// Capturing a task: the sheet's rules in use, and "Day is full" offering without ever blocking.
final class AddTaskUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(sample: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"] + (sample ? ["-JamaalSampleData"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func openAdd(_ app: XCUIApplication, title: String) {
        let add = app.buttons["addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let field = app.textFields["Title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(title)
    }

    @MainActor
    func testAddingAnImportantTaskDatesItTodayAndItAppearsOnTheList() throws {
        let app = launch(sample: false)
        openAdd(app, title: "Renew the passport")
        app.buttons["High"].tap()
        XCTAssertTrue(app.buttons["Add for today"].exists || app.staticTexts["Add for today"].exists)
        app.buttons["addTaskButton"].tap()
        XCTAssertTrue(app.staticTexts["Renew the passport"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testTheButtonStaysQuietUntilThereIsATitle() throws {
        let app = launch(sample: false)
        let add = app.buttons["addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let button = app.buttons["addTaskButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertFalse(button.isEnabled)
    }

    @MainActor
    func testADayThatTipsOverOffersTomorrowButNeverBlocks() throws {
        let app = launch(sample: true)
        openAdd(app, title: "Sort the loft boxes")
        app.buttons["High"].tap()
        app.buttons["2h+"].tap()
        app.buttons["addTaskButton"].tap()

        XCTAssertTrue(app.buttons["dayFullOffer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Day is full'")).firstMatch.exists)
        app.buttons["addAnyway"].tap()
        XCTAssertTrue(app.staticTexts["Sort the loft boxes"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testTakingTheOfferMovesItOffToday() throws {
        let app = launch(sample: true)
        openAdd(app, title: "Sort the loft boxes")
        app.buttons["High"].tap()
        app.buttons["2h+"].tap()
        app.buttons["addTaskButton"].tap()
        XCTAssertTrue(app.buttons["dayFullOffer"].waitForExistence(timeout: 5))
        app.buttons["dayFullOffer"].tap()
        // It is saved for another day, so it isn't on today's list.
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Sort the loft boxes"].exists)
    }
}
