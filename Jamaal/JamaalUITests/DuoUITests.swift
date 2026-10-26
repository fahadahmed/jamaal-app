//
//  DuoUITests.swift
//  JamaalUITests
//

import XCTest

/// The iPhone Duo's displays (#329). These run only on the iPhone Duo simulator (model `iPhone19,4`) and skip everywhere else. A Duo
/// that is closed shows the **outer** display: compact width, with the tab bar and toolbar moved into pills on the right, which takes
/// 84 points off the width. (The open poses can be set in Device Hub only, so they are checked by hand; see the PR.)
final class DuoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone19,4", "needs the iPhone Duo simulator")
    }

    @MainActor
    func testTodayUsesTheWidthBesideTheSidePills() {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0"]
        app.launch()
        let strip = app.buttons["wellbeingStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 15))
        let window = app.windows.firstMatch.frame
        // The content area is the window less the side pills (84 pt) and the margins; Today was 84 pt narrower than that and off-centre.
        XCTAssertLessThan(strip.frame.minX, 40, "Today starts at the normal margin, not pushed in")
        XCTAssertGreaterThan(strip.frame.width, window.width - 84 - 70, "Today uses the width the side pills leave")
        XCTAssertLessThanOrEqual(strip.frame.maxX, window.width - 84, "and stays clear of the pills")
    }
}
