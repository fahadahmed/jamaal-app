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

    @MainActor
    func testAnUpcomingAnchorCannotBeTickedButAGroupOpensAndItsOpenMemberCanBe() throws {
        let app = launch()
        // The school run opens in an hour: its tick is disabled.
        let school = app.buttons["Mark School run attended"]
        XCTAssertTrue(school.waitForExistence(timeout: 10))
        XCTAssertFalse(school.isEnabled)

        // Salah is one grouped row; open it and attend the open window (Dhuhr).
        let group = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Salah'")).firstMatch
        XCTAssertTrue(group.exists)
        group.tap()
        let dhuhr = app.buttons["Mark Dhuhr attended"]
        if !dhuhr.waitForExistence(timeout: 5) { print("HIERARCHY", app.debugDescription) }
        XCTAssertTrue(dhuhr.exists)
        XCTAssertTrue(dhuhr.isEnabled)
        dhuhr.tap()
        XCTAssertTrue(app.buttons["Undo Dhuhr"].waitForExistence(timeout: 5))
        app.buttons["Undo Dhuhr"].tap()
        XCTAssertTrue(app.buttons["Mark Dhuhr attended"].waitForExistence(timeout: 5))
    }

    /// Scrolls until `element` is on screen (Today is longer than a phone).
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    @MainActor
    func testACountedHabitStepsUpAndDown() throws {
        let app = launch()
        let add = app.buttons["Add one to Water"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        reveal(add, in: app)
        XCTAssertTrue(app.staticTexts["3 of 8"].exists)
        add.tap()
        XCTAssertTrue(app.staticTexts["4 of 8"].waitForExistence(timeout: 5))
        app.buttons["Take one from Water"].tap()
        XCTAssertTrue(app.staticTexts["3 of 8"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAnAvoidHabitCanBeHeldAndTakenBack() throws {
        let app = launch()
        let held = app.buttons["Held today: Late-night scrolling"]
        XCTAssertTrue(held.waitForExistence(timeout: 10))
        reveal(held, in: app)
        XCTAssertTrue(app.staticTexts["None yet · up to 1"].exists)
        held.tap()
        let undo = app.buttons["Undo held today for Late-night scrolling"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Held today"].exists)
        undo.tap()
        XCTAssertTrue(app.buttons["Held today: Late-night scrolling"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testABinaryHabitCanBeTickedAndAGroupOpensIntoItsHabits() throws {
        let app = launch()
        let floss = app.buttons["Mark Floss done"]
        XCTAssertTrue(floss.waitForExistence(timeout: 10))
        reveal(floss, in: app)
        floss.tap()
        XCTAssertTrue(app.buttons["Mark Floss not done"].waitForExistence(timeout: 5))

        let pill = app.buttons["Morning, 2 of 3"]
        for _ in 0..<5 where !pill.exists { app.swipeDown() }
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        let journal = app.buttons["Mark Journal done"]
        XCTAssertTrue(journal.waitForExistence(timeout: 5))
        journal.tap()
        XCTAssertTrue(app.buttons["Morning, 3 of 3"].waitForExistence(timeout: 5))
    }
}
