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

    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    /// A phone held wide (an iPhone Duo's inner display, landscape): regular width and at least 700 pt, so the Habits | Anchors segment
    /// keeps its switch above the list and the picked item opens beside it.
    @MainActor
    private func launchWide(_ extra: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalDayStartMinute", "0", "-JamaalWidthClass", "regular", "-JamaalTab", "habits"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testAnchorsInAWideWindowOpenARuleBesideTheList() {
        let app = launchWide(["-JamaalAnchorRules"])
        XCTAssertTrue(app.buttons["segment-anchors"].waitForExistence(timeout: 10), "the switch stays above the list")
        XCTAssertTrue(app.staticTexts["Pick an Anchor rule to see it here."].exists, "an empty pane beside the rules")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'School run'")).firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["anchorPane"].waitForExistence(timeout: 5), "the rule opens in the pane")
        XCTAssertTrue(app.buttons["segment-anchors"].exists, "and the list with its switch is still there")
    }

    @MainActor
    func testHabitsInAWideWindowHaveAPaneBesideTheList() {
        let app = launchWide(["-JamaalSampleData"])
        XCTAssertTrue(app.buttons["segment-habits"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Pick a habit to see it here."].exists)
    }
}
