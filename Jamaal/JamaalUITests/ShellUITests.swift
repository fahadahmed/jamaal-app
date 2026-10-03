//
//  ShellUITests.swift
//  JamaalUITests
//

import XCTest

/// The shell as a person meets it. On a phone the tab bar has four tabs and Anchors is a segment of Habits.
final class ShellUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testThePhoneTabBarHasFourTabsAndAnchorsIsASegmentOfHabits() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "the phone layout")
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        for title in ["Today", "Habits", "Wellbeing", "Settings"] {
            XCTAssertTrue(tabBar.buttons[title].exists, "\(title) is a tab")
        }
        XCTAssertFalse(tabBar.buttons["Anchors"].exists, "Anchors isn't a tab on a phone")

        tabBar.buttons["Habits"].tap()
        let segment = app.segmentedControls.firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5))
        XCTAssertTrue(segment.buttons["Habits"].exists)
        XCTAssertTrue(segment.buttons["Anchors"].exists)

        segment.buttons["Anchors"].tap()
        XCTAssertTrue(app.staticTexts["Prayer times, the school run, bin night."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAnEmptyDayIsStatedCalmly() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"]
        app.launch()
        let headline = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Your day is blank'")).firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
    }
}
