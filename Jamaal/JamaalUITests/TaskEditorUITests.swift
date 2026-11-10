//
//  TaskEditorUITests.swift
//  JamaalUITests
//

import XCTest

/// Task detail as the editor (TK-02): every field changes where it stands and saves, with no Edit, Save or Cancel; leaving a changed
/// task offers one Undo; a future task's primary is Move to today.
final class TaskEditorUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"] + extra
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
    func testThereIsNoEditSaveOrCancel() throws {
        let app = launch()
        open("Call the clinic back", in: app)
        XCTAssertTrue(app.buttons["detailRow-Effort"].waitForExistence(timeout: 5))
        for name in ["Edit", "Save", "Cancel"] { XCTAssertFalse(app.buttons[name].exists, name) }
    }

    @MainActor
    func testChangingEffortSavesAtOnceAndLeavingOffersOneUndo() throws {
        let app = launch()
        open("Call the clinic back", in: app)
        XCTAssertFalse(app.staticTexts["savedTick"].exists)
        app.buttons["detailRow-Effort"].tap()
        XCTAssertTrue(app.buttons["effort-45"].waitForExistence(timeout: 5))
        app.buttons["effort-45"].tap()                                           // saves and pops back
        let row = app.buttons["detailRow-Effort"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("45 min"), row.label)
        XCTAssertTrue(app.staticTexts["savedTick"].exists || app.otherElements["savedTick"].exists || app.descendants(matching: .any)["savedTick"].exists)

        app.swipeDown(velocity: .fast)                                           // leave the task
        let undo = app.buttons["editUndoButton"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "one undo for the visit")
        undo.tap()
        open("Call the clinic back", in: app)
        let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '15 min'"), object: app.buttons["detailRow-Effort"])
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 8), .completed, "it is back as it was")
    }

    /// Stepping *Other…* more than once keeps the picker open (it used to close whenever a step landed on a listed option, such as 45).
    @MainActor
    func testTheOtherStepperCanBeSteppedRepeatedlyWithoutClosing() throws {
        let app = launch()
        open("Call the clinic back", in: app)                                   // 15 min
        app.buttons["detailRow-Effort"].tap()
        let other = app.buttons["effort-other"]
        XCTAssertTrue(other.waitForExistence(timeout: 5))
        other.tap()
        let stepper = app.steppers["effortStepper"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        for _ in 0..<4 { stepper.buttons.element(boundBy: 1).tap() }               // 30, 45, 60, 75: three of them are listed options
        XCTAssertTrue(app.steppers["effortStepper"].exists, "the picker is still open")
        app.buttons["pickerBack"].tap()
        let row = app.buttons["detailRow-Effort"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("1h 15m"), row.label)
    }


    @MainActor
    func testTheTitleEditsInPlace() throws {
        let app = launch()
        open("Reply to Sam", in: app)
        let title = app.textFields["detailTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        title.typeText("Reply to Sam today\n")
        XCTAssertEqual(app.textFields["detailTitle"].value as? String, "Reply to Sam today")
        XCTAssertTrue(app.descendants(matching: .any)["savedTick"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAFutureTaskOffersMoveToTodayInsteadOfBeginAndItCountsOnTodayAfterwards() throws {
        let app = launch(extra: ["-JamaalComingUp"])
        XCTAssertTrue(app.staticTexts["Draft the architecture review"].waitForExistence(timeout: 10))
        let row = app.buttons["comingUpRow"]
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        row.tap()
        let task = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Groceries'")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        XCTAssertTrue(app.buttons["moveToToday"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["beginButton"].exists, "a future task isn't actionable yet")
        XCTAssertTrue(app.staticTexts["futureNote"].exists, "it says when it will count")
        app.buttons["moveToToday"].tap()
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 5), "now it is for today")
    }
}
