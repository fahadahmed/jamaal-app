//
//  TodayToolbarUITests.swift
//  JamaalUITests
//

import XCTest

/// The toolbar's category filter, the carried-over row, and the blank day.
final class TodayToolbarUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func chooseFilter(_ name: String, in app: XCUIApplication) {
        let filter = app.buttons["filterButton"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        filter.tap()
        let item = app.buttons[name]
        XCTAssertTrue(item.waitForExistence(timeout: 5), name)
        item.tap()
    }

    private func taskTick(_ title: String, in app: XCUIApplication) -> XCUIElement { app.buttons["Mark \(title) done"] }

    @MainActor
    func testTheFilterNarrowsTasksAndTheChipClearsIt() throws {
        let app = launch()
        XCTAssertTrue(taskTick("Call the clinic back", in: app).waitForExistence(timeout: 10))
        chooseFilter("Family", in: app)

        XCTAssertTrue(app.buttons["filterChip"].waitForExistence(timeout: 5))
        XCTAssertTrue(taskTick("Book Yusuf's swimming lessons", in: app).exists)
        XCTAssertFalse(taskTick("Call the clinic back", in: app).exists)
        XCTAssertFalse(taskTick("Draft the architecture review", in: app).exists)
        // The meter still reads the whole day.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'whole day'")).firstMatch.exists
                      || app.otherElements.matching(NSPredicate(format: "value CONTAINS 'whole day'")).firstMatch.exists)

        app.buttons["filterChip"].tap()
        XCTAssertTrue(taskTick("Call the clinic back", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["filterChip"].exists)
    }

    @MainActor
    func testAnEmptyFilterSaysSoAndShowAllBringsEverythingBack() throws {
        let app = launch()
        // Drop the only Family task, then filter by Family.
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Book Yusuf's swimming lessons")).firstMatch
        for _ in 0..<5 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        app.buttons["dropButton"].tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Drop' AND identifier != 'dropButton'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        chooseFilter("Family", in: app)
        XCTAssertTrue(app.staticTexts["Nothing in Family today."].waitForExistence(timeout: 5))
        app.buttons["showAll"].tap()
        XCTAssertTrue(taskTick("Call the clinic back", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Nothing in Family today."].exists)
    }

    @MainActor
    func testThePickUpRowOffersTheTaskBackAndDismissesQuietly() throws {
        let app = launch(["-JamaalPickUp"])
        let row = app.otherElements["pickUpRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '42 min logged on'")).firstMatch.exists)
        app.buttons["Pick it back up"].tap()
        XCTAssertTrue(app.buttons["focusChip"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["pickUpRow"].exists)
    }

    @MainActor
    func testDismissingThePickUpRowPutsItAway() throws {
        let app = launch(["-JamaalPickUp"])
        XCTAssertTrue(app.otherElements["pickUpRow"].waitForExistence(timeout: 10))
        app.buttons["Dismiss"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.otherElements["pickUpRow"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
        XCTAssertFalse(app.buttons["focusChip"].exists)
    }

    @MainActor
    func testTheToolbarStaysPutWhileTodayScrolls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        let add = app.buttons["addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        let before = add.frame
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(add.isHittable, "Add is still reachable after scrolling")
        XCTAssertEqual(add.frame.minY, before.minY, accuracy: 2)
        add.tap()
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
    }
}
