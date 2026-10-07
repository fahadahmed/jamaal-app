//
//  MinutesByHandUITests.swift
//  JamaalUITests
//

import XCTest

/// A timed habit's minutes added without the timer (the sample "Read" habit starts at 12 of 20 min).
final class MinutesByHandUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    @MainActor
    private func openSheet(_ app: XCUIApplication) {
        let add = app.buttons["Add minutes to Read"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        reveal(add, in: app)
        add.tap()
        XCTAssertTrue(app.buttons["addMinutesButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTheSheetShowsTheHabitAndTodaysProgressAndStartsAtTenMinutes() throws {
        let app = launch()
        openSheet(app)
        XCTAssertEqual(app.staticTexts["addMinutesSubtitle"].label, "Read · today, 12 of 20 min so far")
        XCTAssertEqual(app.buttons["addMinutesButton"].label, "Add 10 min")
        XCTAssertEqual(app.descendants(matching: .any)["minutesValue"].label, "10 minutes")
    }

    @MainActor
    func testTheStepperMovesInFivesAndTheButtonFollows() throws {
        let app = launch()
        openSheet(app)
        app.buttons["minutesLess"].tap()
        XCTAssertEqual(app.buttons["addMinutesButton"].label, "Add 5 min")
        app.buttons["minutesMore"].tap(); app.buttons["minutesMore"].tap()
        XCTAssertEqual(app.buttons["addMinutesButton"].label, "Add 15 min")
    }

    @MainActor
    func testAddingFiveMinutesRaisesTodaysTotalOnTheRow() throws {
        let app = launch()
        openSheet(app)
        app.buttons["minutesLess"].tap()
        app.buttons["addMinutesButton"].tap()
        XCTAssertTrue(app.staticTexts["17 of 20 min"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReachingTheTargetMarksTheHabitDone() throws {
        let app = launch()
        openSheet(app)
        app.buttons["addMinutesButton"].tap()                                          // 12 + 10 = 22 of 20
        XCTAssertTrue(app.staticTexts["22 of 20 min"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add minutes to Read"].waitForExistence(timeout: 2))   // done: no more Begin or Add
    }

    @MainActor
    func testAMistakeCanBeTakenBackOut() throws {
        let app = launch()
        openSheet(app)
        app.buttons["minutesLess"].tap()
        app.buttons["addMinutesButton"].tap()
        XCTAssertTrue(app.staticTexts["17 of 20 min"].waitForExistence(timeout: 5))
        openSheet(app)
        XCTAssertEqual(app.staticTexts["addMinutesSubtitle"].label, "Read · today, 17 of 20 min so far")
        let remove = app.buttons["removeMinutes"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '5 min · '")).firstMatch.exists)
        remove.tap()
        let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Read · today, 12 of 20 min so far'"), object: app.staticTexts["addMinutesSubtitle"])
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 5), .completed)
        XCTAssertFalse(remove.exists)
    }

    @MainActor
    func testItIsAlsoOnTheHabitsDetail() throws {
        let app = launch()
        app.tabBars.buttons["Habits"].tap()
        let habit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read'")).firstMatch
        XCTAssertTrue(habit.waitForExistence(timeout: 10))
        habit.tap()
        let add = app.buttons["Add minutes to Read"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.buttons["addMinutesButton"].waitForExistence(timeout: 5))
        app.buttons["addMinutesButton"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '22 of 20 min'")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testItStaysOpenWhenReadOnlyBecauseItIsLivingTheDay() throws {
        let app = launch(["-JamaalAccess", "readOnly"])
        XCTAssertTrue(app.buttons["notNow"].waitForExistence(timeout: 10))
        app.buttons["notNow"].tap()
        openSheet(app)
        XCTAssertFalse(app.descendants(matching: .any)["lockedSheet"].exists)
        app.buttons["addMinutesButton"].tap()
        XCTAssertTrue(app.staticTexts["22 of 20 min"].waitForExistence(timeout: 5))
    }
}
