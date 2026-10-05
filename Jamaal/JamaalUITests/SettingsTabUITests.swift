//
//  SettingsTabUITests.swift
//  JamaalUITests
//

import XCTest

/// The Settings tab: its home, Capacity and day, and Categories.
final class SettingsTabUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"] + extra
        app.launch()
        let tab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        return app
    }

    @MainActor
    private func open(_ id: String, in app: XCUIApplication) {
        let row = app.buttons[id]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    @MainActor
    func testTheHomeShowsTheNormalDayAndTheNumberOfCategories() throws {
        let app = launch()
        let capacity = app.buttons["settings-capacity"]
        XCTAssertTrue(capacity.waitForExistence(timeout: 10))
        XCTAssertTrue(capacity.label.contains("3h · 08:00–19:00"), capacity.label)
        XCTAssertTrue(app.buttons["settings-categories"].label.contains("3"), app.buttons["settings-categories"].label)
    }

    @MainActor
    func testTheNormalDayStepsByAQuarterHourAndLowAndHighFollow() throws {
        let app = launch()
        open("settings-capacity", in: app)
        XCTAssertEqual(app.staticTexts["normalDay"].label, "3h")
        XCTAssertEqual(app.staticTexts["levels"].label, "Low is 2h, high is 4h.")
        app.buttons["Add one to normal day"].tap()
        XCTAssertEqual(app.staticTexts["normalDay"].label, "3h 15m")
        XCTAssertEqual(app.staticTexts["levels"].label, "Low is 2h 10m, high is 4h 20m.")
        app.buttons["Take one from normal day"].tap()
        app.buttons["Take one from normal day"].tap()
        XCTAssertEqual(app.staticTexts["normalDay"].label, "2h 45m")
    }

    @MainActor
    func testAWeekdayLevelChangesAndTheNormalDayShowsOnTheHomeRow() throws {
        let app = launch()
        open("settings-capacity", in: app)
        let sunday = app.segmentedControls["level-7"]
        reveal(sunday, in: app)
        XCTAssertTrue(sunday.buttons["Low"].isSelected)
        sunday.buttons["High"].tap()
        XCTAssertTrue(sunday.buttons["High"].isSelected)
        let monday = app.segmentedControls["level-1"]
        reveal(monday, in: app)
        XCTAssertTrue(monday.buttons["Med"].isSelected)
    }

    @MainActor
    func testPlanningBeforeTheDayEndsGetsAQuietNote() throws {
        // The default planning time is 20:00, after a 19:00 end, so there is no note.
        let app = launch()
        open("settings-capacity", in: app)
        XCTAssertTrue(app.staticTexts["levels"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["planningNote"].exists)
    }

    @MainActor
    func testTheSuggestionCanBeAcceptedAndNotOfferedAgain() throws {
        let app = launch(["-JamaalNormalDayHistory"])
        open("settings-capacity", in: app)
        let set = app.buttons["setSuggestion"]
        XCTAssertTrue(set.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["normalDay"].label, "4h")
        XCTAssertTrue(set.label.contains("2h 45m"), set.label)
        set.tap()
        XCTAssertEqual(app.staticTexts["normalDay"].label, "2h 45m")
        XCTAssertFalse(app.buttons["setSuggestion"].exists)
    }

    @MainActor
    func testDecliningTheSuggestionHidesIt() throws {
        let app = launch(["-JamaalNormalDayHistory"])
        open("settings-capacity", in: app)
        let not = app.buttons["declineSuggestion"]
        XCTAssertTrue(not.waitForExistence(timeout: 10))
        not.tap()
        XCTAssertFalse(app.buttons["setSuggestion"].exists)
        XCTAssertEqual(app.staticTexts["normalDay"].label, "4h")
    }

    // MARK: Categories

    @MainActor
    func testTheCategoriesAreListedAndOneIsRenamed() throws {
        let app = launch()
        open("settings-categories", in: app)
        XCTAssertTrue(app.buttons["category-Work"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["category-Personal"].exists && app.buttons["category-Family"].exists)
        app.buttons["category-Work"].tap()
        let name = app.textFields["categoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.clearAndType("Day job")
        app.buttons["categoryDone"].tap()
        XCTAssertTrue(app.buttons["category-Day job"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testADuplicateOrBlankNameIsRefusedCalmly() throws {
        let app = launch()
        open("settings-categories", in: app)
        app.buttons["category-Work"].tap()
        let name = app.textFields["categoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.clearAndType("family")
        app.buttons["categoryDone"].tap()
        XCTAssertTrue(app.staticTexts["You already have a label with that name."].waitForExistence(timeout: 5))
        name.clearAndType("   ")
        app.buttons["categoryDone"].tap()
        XCTAssertTrue(app.staticTexts["Give it a name first."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testALabelIsAddedArchivedAndRestored() throws {
        let app = launch()
        open("settings-categories", in: app)
        app.buttons["addCategory"].tap()
        let name = app.textFields["newCategoryName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Errands")
        app.buttons["newCategoryAdd"].tap()
        let errands = app.buttons["category-Errands"]
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        app.buttons["categoryArchive"].tap()
        XCTAssertFalse(app.buttons["category-Errands"].waitForExistence(timeout: 2))
        let toggle = app.buttons["categoriesArchivedToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        let restore = app.buttons["Restore Errands"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.buttons["category-Errands"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testALabelMovesDownTheList() throws {
        let app = launch()
        open("settings-categories", in: app)
        app.buttons["category-Personal"].tap()
        app.buttons["categoryDown"].tap()
        app.buttons["categoryDone"].tap()
        let personal = app.buttons["category-Personal"], family = app.buttons["category-Family"]
        XCTAssertTrue(personal.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(personal.frame.minY, family.frame.minY)
    }
}

private extension XCUIElement {
    /// Replaces the text of a field.
    func clearAndType(_ text: String) {
        guard let current = value as? String else { typeText(text); return }
        tap()
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}
