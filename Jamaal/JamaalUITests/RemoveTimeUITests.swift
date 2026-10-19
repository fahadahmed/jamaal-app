//
//  RemoveTimeUITests.swift
//  JamaalUITests
//

import XCTest

/// Removing a time from a habit or an Anchor rule while making it. The sheet is still on screen for a moment after the time is
/// gone from the draft, and used to read the removed entry and take the app down.
final class RemoveTimeUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalFakePlaces"]
        app.launch()
        let tab = app.tabBars.buttons["Habits"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        return app
    }

    @MainActor
    func testRemovingATimeFromAHabitKeepsTheAppAndTheForm() throws {
        let app = launch()
        let add = app.buttons["addHabit"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        app.buttons["kind-binary"].tap()
        let name = app.textFields["habitName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Medication")
        app.buttons["addWindow"].tap()
        XCTAssertTrue(app.buttons["window-1"].waitForExistence(timeout: 5))
        app.buttons["window-1"].tap()
        let remove = app.buttons["Remove this time"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        // The app is still here, back on the form, with one time left.
        XCTAssertTrue(app.textFields["habitName"].waitForExistence(timeout: 5), "the app closed or the form went")
        XCTAssertTrue(app.buttons["window-0"].exists)
        XCTAssertFalse(app.buttons["window-1"].exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testRemovingATimeFromAnAnchorRuleKeepsTheAppAndTheForm() throws {
        let app = launch()
        let segment = app.buttons["segment-anchors"]
        XCTAssertTrue(segment.waitForExistence(timeout: 5))
        segment.tap()
        app.buttons["addAnchorRule"].tap()
        let custom = app.buttons["type-custom"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        custom.tap()
        let addSlot = app.buttons["addSlot"]
        XCTAssertTrue(addSlot.waitForExistence(timeout: 5))
        addSlot.tap()
        addSlot.tap()
        XCTAssertTrue(app.buttons["slot-1"].waitForExistence(timeout: 5))
        app.buttons["slot-1"].tap()
        let remove = app.buttons["Remove this time"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.buttons["slot-0"].waitForExistence(timeout: 5), "the app closed or the form went")
        XCTAssertFalse(app.buttons["slot-1"].exists)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
