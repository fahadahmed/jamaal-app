//
//  FoldContinuityUITests.swift
//  JamaalUITests
//

import XCTest

/// Folding or unfolding a foldable iPhone changes the width class under the app. Nothing in progress may be lost on the way (#329,
/// docs/journeys/app-flow.md, "iPhone Duo", point 3). `-JamaalWidthClass` forces the class the app's layouts read and puts a control in the
/// left edge that switches it, which stands in for the fold. Night Planning is not tested here: a full-screen cover takes its size class from
/// UIKit, which this switch cannot reach, so it is checked on a real fold in Device Hub.
final class FoldContinuityUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // A phone is narrower than two panes need, so it starts as one column and nothing changes when the class is forced; the fold is
        // only a change of layout on a wide display (an iPad, or the inner display of an iPhone Duo).
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "needs a wide display")
    }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWidthClass", "regular"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func fold(_ app: XCUIApplication, to expected: String) {
        let toggle = app.buttons["debugToggleWidthClass"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, expected)
        Thread.sleep(forTimeInterval: 1.5)                                   // the layout settles
    }

    @MainActor
    func testAnOpenTaskSurvivesFoldingAndUnfolding() {
        let app = launch(["-JamaalOpenTask"])
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 10), "regular: the task is in the panel")
        fold(app, to: "compact")
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 5), "compact: the same task is in a sheet")
        XCTAssertTrue(app.staticTexts["Call the clinic back"].exists)
        fold(app, to: "regular")
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 5), "regular again: still open")
        XCTAssertTrue(app.staticTexts["Call the clinic back"].exists)
    }

    @MainActor
    func testAHalfTypedTaskSurvivesFoldingAndUnfolding() {
        let app = launch(["-JamaalOpenAdd"])
        let field = app.textFields["Title"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Renew the passport")
        fold(app, to: "compact")
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5), "compact: Add task is open")
        XCTAssertEqual(app.textFields["Title"].value as? String, "Renew the passport", "and keeps what was typed")
        fold(app, to: "regular")
        XCTAssertEqual(app.textFields["Title"].value as? String, "Renew the passport")
    }
}
