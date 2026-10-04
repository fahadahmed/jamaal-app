//
//  HabitsTabUITests.swift
//  JamaalUITests
//

import XCTest

/// The Habits tab: the overview, a habit's detail, correcting a past day, pause and archive.
final class HabitsTabUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launchOnHabits() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        let tab = app.tabBars.buttons["Habits"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        return app
    }

    @MainActor
    private func row(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    @MainActor
    func testTheOverviewShowsGroupsStatusesAPausedHabitAndTheArchive() throws {
        let app = launchOnHabits()
        XCTAssertTrue(app.staticTexts["Habits"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Morning, 2 of 3 today"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("Water", in: app).exists)
        XCTAssertTrue(row("Water", in: app).label.contains("Counted · 3 of 8 today"))
        let reading = row("Reading before bed", in: app)
        reveal(reading, in: app)
        XCTAssertTrue(reading.label.contains("Paused · travel · resumes"))
        let archived = app.buttons["archivedToggle"]
        reveal(archived, in: app)
        archived.tap()
        XCTAssertTrue(app.buttons["Restore Cold shower"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testARestoredHabitJoinsTheList() throws {
        let app = launchOnHabits()
        let archived = app.buttons["archivedToggle"]
        reveal(archived, in: app)
        archived.tap()
        app.buttons["Restore Cold shower"].tap()
        XCTAssertTrue(row("Cold shower", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Restore Cold shower"].exists)
    }

    @MainActor
    func testTheDetailShowsTodayTheGridAndTheCounterWorks() throws {
        let app = launchOnHabits()
        row("Water", in: app).tap()
        XCTAssertTrue(app.staticTexts["COUNTED · 8 A DAY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 of 8 today"].exists)
        app.buttons["Add one to Water"].tap()
        XCTAssertTrue(app.staticTexts["4 of 8 today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["habitRead"].exists || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Reached the target on'")).firstMatch.exists)
    }

    @MainActor
    func testAPastDayCanBeCorrectedFromTheGrid() throws {
        let app = launchOnHabits()
        row("Water", in: app).tap()
        let cells = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Day ' AND label ENDSWITH 'partly done'"))
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 5), "a day that stopped at four is partly done")
        cells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["CORRECT A DAY"].waitForExistence(timeout: 5))
        app.buttons["Add one to Water on that day"].tap()
        app.buttons["correctionDone"].tap()
        XCTAssertTrue(app.staticTexts["COUNTED · 8 A DAY"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBackReturnsToTheList() throws {
        let app = launchOnHabits()
        row("Water", in: app).tap()
        XCTAssertTrue(app.staticTexts["COUNTED · 8 A DAY"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(row("Water", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["COUNTED · 8 A DAY"].exists)
    }

    @MainActor
    func testPausingFromTheDetailShowsInTheOverview() throws {
        let app = launchOnHabits()
        row("Floss", in: app).tap()
        app.buttons["habitMenu"].tap()
        app.buttons["Pause…"].tap()
        let confirm = app.buttons["pauseConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pausedNote"].waitForExistence(timeout: 5))
        // Let the sheet finish going away before leaving the detail.
        let back = app.buttons["Back"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: back)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 5), .completed)
        back.tap()
        let floss = row("Floss", in: app)
        if !floss.waitForExistence(timeout: 5) { print("HIERARCHY", app.debugDescription) }
        XCTAssertTrue(floss.exists)
        XCTAssertTrue(floss.label.contains("Paused · travel · until you resume"), floss.label)
    }

    @MainActor
    func testArchivingFromTheDetailMovesItToTheArchive() throws {
        let app = launchOnHabits()
        row("Floss", in: app).tap()
        app.buttons["habitMenu"].tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["Habits"].waitForExistence(timeout: 5))
        XCTAssertFalse(row("Floss", in: app).exists)
    }
}
