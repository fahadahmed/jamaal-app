//
//  PaneLayoutUITests.swift
//  JamaalUITests
//

import XCTest

/// Regular width alone does not mean two panes (#329): an iPhone Duo held fully open in portrait is regular width but 669 pt wide, and the
/// design draws one column there. `-JamaalWidthClass regular` on a phone is the same situation: regular width, narrow window.
final class PaneLayoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "needs a narrow window")
    }

    @MainActor
    func testARegularButNarrowWindowIsOneColumnWithTheTaskInASheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWidthClass", "regular", "-JamaalOpenTask"]
        app.launch()
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 10), "the task opens")
        XCTAssertFalse(app.descendants(matching: .any)["detailPanel"].exists, "but not in a pane beside the list")
    }

    @MainActor
    func testARegularButNarrowWindowStillHasFourTabsAndNoAnchorsTab() {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWidthClass", "regular"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Habits"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Anchors"].exists, "Anchors is a segment of Habits on a phone, at any width")
    }

    @MainActor
    func testSettingsInARegularButNarrowWindowIsOneList() {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWidthClass", "regular", "-JamaalTab", "settings"]
        app.launch()
        XCTAssertTrue(app.buttons["settings-capacity"].waitForExistence(timeout: 10), "the list is there")
        XCTAssertFalse(app.staticTexts["Pick a setting to see it here."].exists, "with no empty pane beside it")
    }
}

