//
//  NextGapUITests.swift
//  JamaalUITests
//

import XCTest

/// The next gap line (#410): "Free until Dentist · 2h. Fits: …". `-JamaalNextGap` pretends it is 09:00 and adds a fixed Anchor at 11:00.
final class NextGapUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testTheLineNamesTheGapAndTheTaskThatFitsAndTappingItOpensTheTask() throws {
        let app = launch(["-JamaalNextGap"])
        let line = app.buttons["nextGap"]
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        XCTAssertEqual(line.label, "Free until Dentist · 2h. Fits: Draft the architecture review.")
        line.tap()
        XCTAssertTrue(app.buttons["detailRow-Effort"].waitForExistence(timeout: 5), "the task opened")
        XCTAssertEqual(app.textFields["detailTitle"].value as? String, "Draft the architecture review")
    }

    @MainActor
    func testThereIsNoLineWhenThereIsNoFreeTimeLeftBeforeAnAnchor() throws {
        let app = launch(["-JamaalNextGapAfterHours"])                     // pretends it is 20:00, after the working day
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["nextGap"].exists)
    }
}
