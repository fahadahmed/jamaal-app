//
//  TaskDetailUITests.swift
//  JamaalUITests
//

import XCTest

/// A task's detail sheet and Defer: the note's checklist, the table, and the three actions.
final class TaskDetailUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        return app
    }

    @MainActor
    private func open(_ title: String, in app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        for _ in 0..<5 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(title) row")
        row.tap()
    }

    @MainActor
    func testTheDetailShowsTheTableAndTheNoteChecklistToggles() throws {
        let app = launch()
        open("Call the clinic back", in: app)

        XCTAssertTrue(app.staticTexts["Effort"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["15 min"].exists)
        XCTAssertTrue(app.staticTexts["Deferred twice"].exists || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Deferred twice'")).firstMatch.exists)

        let box = app.buttons["Are Thursday mornings still open?"]
        XCTAssertTrue(box.waitForExistence(timeout: 5))
        XCTAssertEqual(box.value as? String, "Not done")
        box.tap()
        XCTAssertEqual(app.buttons["Are Thursday mornings still open?"].value as? String, "Done")
    }

    @MainActor
    func testMarkDoneFromTheDetailCompletesTheTask() throws {
        let app = launch()
        open("Book Yusuf's swimming lessons", in: app)
        let done = app.buttons["markDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["Mark Book Yusuf's swimming lessons not done"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testTheFirstDeferralMovesItToTomorrowAtOnce() throws {
        let app = launch()
        open("Book Yusuf's swimming lessons", in: app)
        app.buttons["deferButton"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Mark Book Yusuf's swimming lessons done"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTheThirdDeferralOpensThePickerWithAReasonAndMoves() throws {
        let app = launch()
        open("Call the clinic back", in: app)
        app.buttons["deferButton"].tap()
        XCTAssertTrue(app.staticTexts["Third time"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This one keeps slipping. Pick a day that actually works."].exists)
        app.buttons["Too much on"].tap()
        app.buttons["moveButton"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Mark Call the clinic back done"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDroppingAsksFirstAndThenTheTaskLeavesToday() throws {
        let app = launch()
        open("Book Yusuf's swimming lessons", in: app)
        app.buttons["dropButton"].tap()
        // The sheet's own Drop button has an identifier; the confirmation's doesn't.
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Drop' AND identifier != 'dropButton'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Mark Book Yusuf's swimming lessons done"].waitForExistence(timeout: 2))
    }
}
