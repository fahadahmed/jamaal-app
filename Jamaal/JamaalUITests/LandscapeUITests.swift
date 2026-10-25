//
//  LandscapeUITests.swift
//  JamaalUITests
//

import XCTest

/// An iPhone held sideways is about 390 points tall: the layout must still fill the width, keep its buttons reachable and give the
/// content room (#315). Each test launches in portrait and then rotates, because that is what a person does.
final class LandscapeUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    @MainActor
    private func launchSideways(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0"] + extra
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        return app
    }

    @MainActor
    func testTodayFillsTheWidthAfterRotating() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let app = launchSideways()
        let strip = app.buttons["wellbeingStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch.frame
        // It was a narrow column (about 340 points of 844) in the middle of the screen.
        XCTAssertGreaterThan(strip.frame.width, window.width * 0.7, "Today should use the width of the screen")
    }

    @MainActor
    func testNightPlanningKeepsItsButtonsOnOneRow() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let app = launchSideways(["-JamaalPlan", "3"])
        let next = app.buttons["planContinue"], skip = app.buttons["planSkip"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertTrue(next.isHittable && skip.isHittable)
        XCTAssertLessThan(abs(next.frame.minY - skip.frame.minY), 12, "Skip sits beside Continue, not under it")
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height - next.frame.maxY, -1)
        XCTAssertGreaterThan(next.frame.minY, app.windows.firstMatch.frame.height * 0.6, "the footer stays at the bottom")
    }

    @MainActor
    func testTaskDetailActionsShareARow() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let app = launchSideways(["-JamaalOpenTask"])
        let begin = app.buttons["beginButton"], done = app.buttons["markDone"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        XCTAssertTrue(begin.isHittable && done.isHittable)
        XCTAssertLessThan(abs(begin.frame.minY - done.frame.minY), 12, "Begin and Mark done are on one row")
    }
}
