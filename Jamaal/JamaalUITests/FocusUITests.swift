//
//  FocusUITests.swift
//  JamaalUITests
//

import XCTest

/// A focus session as a person meets it: Begin from a task's detail, the chip on every tab, the timer, Pause,
/// Finish and Undo, and the settle sheet when a second Begin arrives.
final class FocusUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        return app
    }

    @MainActor
    private func begin(_ title: String, in app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        for _ in 0..<5 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), title)
        row.tap()
        let begin = app.buttons["beginButton"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()
    }

    @MainActor
    func testBeginShowsTheChipOnEveryTabAndItOpensTheTimer() throws {
        let app = launch()
        begin("Draft the architecture review", in: app)
        let chip = app.buttons["focusChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))

        app.tabBars.buttons["Wellbeing"].tap()
        XCTAssertTrue(app.buttons["focusChip"].waitForExistence(timeout: 5), "the chip is on every tab")
        app.tabBars.buttons["Today"].tap()

        app.buttons["focusChip"].tap()
        XCTAssertTrue(app.buttons["finishButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["of 60 min"].exists)
    }

    @MainActor
    func testPauseAndResumeChangeTheButtonNotTheMood() throws {
        let app = launch()
        begin("Draft the architecture review", in: app)
        app.buttons["focusChip"].tap()
        let pause = app.buttons["pauseButton"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        XCTAssertTrue(pause.label.contains("Pause"))
        pause.tap()
        XCTAssertTrue(app.staticTexts["Paused"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pauseButton"].label.contains("Resume"))
        app.buttons["pauseButton"].tap()
        XCTAssertTrue(app.buttons["pauseButton"].label.contains("Pause"))
    }

    @MainActor
    func testFinishAsDoneCompletesTheTaskAndTheToastCanUndoIt() throws {
        let app = launch()
        begin("Draft the architecture review", in: app)
        app.buttons["focusChip"].tap()
        app.buttons["finishButton"].tap()
        let done = app.buttons["doneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        let undo = app.buttons["undoButton"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        undo.tap()
        // Undone: the session is live again, so the chip is back and the task isn't done.
        XCTAssertTrue(app.buttons["focusChip"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Mark Draft the architecture review not done"].exists)
    }

    @MainActor
    func testStopForNowKeepsTheTaskOnTodayAndTheChipGoes() throws {
        let app = launch()
        begin("Draft the architecture review", in: app)
        app.buttons["focusChip"].tap()
        app.buttons["finishButton"].tap()
        app.buttons["stopForNowButton"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["focusChip"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Mark Draft the architecture review done"].exists)
    }

    @MainActor
    func testASecondBeginRaisesTheSettleSheetAndCancelChangesNothing() throws {
        let app = launch()
        begin("Draft the architecture review", in: app)
        XCTAssertTrue(app.buttons["focusChip"].waitForExistence(timeout: 10))
        begin("Book Yusuf's swimming lessons", in: app)
        XCTAssertTrue(app.staticTexts["Settle this one first. Its time is kept whichever you pick."].waitForExistence(timeout: 5))
        app.buttons["settleCancel"].tap()
        // The sheet is gone and the first session is untouched.
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["settleCancel"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["focusChip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["focusChip"].label.contains("Draft the architecture review"))
    }

    @MainActor
    func testSettlingWithStopForNowBeginsTheNextOne() throws {
        let app = launch()
        begin("Draft the architecture review", in: app)
        XCTAssertTrue(app.buttons["focusChip"].waitForExistence(timeout: 10))
        begin("Book Yusuf's swimming lessons", in: app)
        app.buttons["settleStop"].tap()
        // The chip first reads the old task, then the new one once it has begun.
        let next = app.buttons.matching(NSPredicate(format: "identifier == 'focusChip' AND label CONTAINS %@", "Book Yusuf's swimming lessons")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10))
    }

    @MainActor
    func testATimedHabitBeginsFromItsRow() throws {
        let app = launch()
        let begin = app.buttons["Begin Read"]
        for _ in 0..<5 where !(begin.exists && begin.isHittable) { app.swipeUp() }
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        begin.tap()
        let chip = app.buttons["focusChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        XCTAssertTrue(chip.label.contains("Read"))
    }
}
