//
//  TodayUITests.swift
//  JamaalUITests
//

import XCTest

/// Today's interactive parts: the capacity slider and ticking a task. Both are easy to break silently in a
/// SwiftUI refactor, which is what these are for.
final class TodayUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        return app
    }

    @MainActor
    func testTheSampleDayShowsItsTasksAndTheMeter() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Draft the architecture review"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Call the clinic back"].exists)
        XCTAssertTrue(app.otherElements["Today's load"].exists || app.staticTexts["Today's load"].exists)
    }

    @MainActor
    func testTickingATaskMarksItDoneAndUntickingBringsItBack() throws {
        let app = launch()
        let tick = app.buttons["Mark Draft the architecture review done"]
        XCTAssertTrue(tick.waitForExistence(timeout: 10))
        tick.tap()

        // A done task settles at the bottom of the list, so scroll to it.
        let untick = app.buttons["Mark Draft the architecture review not done"]
        for _ in 0..<4 where !(untick.exists && untick.isHittable) { app.swipeUp() }
        XCTAssertTrue(untick.waitForExistence(timeout: 5))
        untick.tap()
        XCTAssertTrue(app.buttons["Mark Draft the architecture review done"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTheCapacitySliderMovesWithAccessibilityAdjustments() throws {
        let app = launch()
        let slider = app.sliders["Capacity for today"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        // The track is the top part of the control, the labels the bottom; touch the far ends of the track.
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.2)).tap()
        XCTAssertEqual(slider.value as? String, "High")
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.2)).tap()
        XCTAssertEqual(slider.value as? String, "Low")
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertEqual(slider.value as? String, "Medium")
    }
}
