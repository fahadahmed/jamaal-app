//
//  CompactTodayUITests.swift
//  JamaalUITests
//

import XCTest

/// Today's top is compact by default (#406): the capacity slider, the Anchors and the Habits fold to a line each, so the tasks sit near
/// the top. `-JamaalCompactToday` gives the real first-launch default, which debug runs otherwise open for the other tests.
final class CompactTodayUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalCompactToday", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        return app
    }

    @MainActor
    func testTheFirstTaskIsOnTheFirstScreenWithoutScrolling() throws {
        let app = launch()
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Draft the architecture review'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(first.isHittable, "the first task is on the first screen")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(first.frame.minY, window.height * 0.75, "and in the upper part of it")
    }

    @MainActor
    func testTheSliderIsFoldedAwayAndTheLevelIsNamedInTheRow() throws {
        let app = launch()
        let toggle = app.buttons["capacityToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertFalse(app.sliders["Capacity for today"].exists)
        let meter = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Today's load")).firstMatch
        XCTAssertTrue((meter.value as? String ?? "").hasPrefix("Medium · "), meter.value as? String ?? "")
        toggle.tap()
        XCTAssertTrue(app.sliders["Capacity for today"].waitForExistence(timeout: 5))
        toggle.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.sliders["Capacity for today"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    func testAnchorsAndHabitsAreOneLineEachUntilOpened() throws {
        let app = launch()
        let anchors = app.buttons["todayAnchorsToggle"]
        let habits = app.buttons["todayHabitsToggle"]
        XCTAssertTrue(anchors.waitForExistence(timeout: 10))
        XCTAssertTrue(habits.waitForExistence(timeout: 5))
        XCTAssertTrue(anchors.label.hasPrefix("Anchors, "), anchors.label)
        XCTAssertTrue(habits.label.contains(" of "), "it says how the habits are going: \(habits.label)")
        XCTAssertFalse(app.buttons["Mark Water done"].exists, "the habit rows are folded")
        XCTAssertFalse(app.staticTexts["Water"].exists)

        habits.tap()
        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 5), "opening shows the habits")
        habits.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["Water"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    func testTodayNoLongerShowsTheWellbeingStrip() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["wellbeingStrip"].exists)
    }
}
