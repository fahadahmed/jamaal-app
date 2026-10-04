//
//  AddHabitUITests.swift
//  JamaalUITests
//

import XCTest

/// Making and editing a habit from the Habits tab.
final class AddHabitUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launchOnHabits(sample: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"] + (sample ? ["-JamaalSampleData"] : [])
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
    private func startAdding(_ app: XCUIApplication, kind: String) {
        let add = app.buttons["addHabit"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let choice = app.buttons[kind]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
    }

    @MainActor
    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    @MainActor
    func testACountedHabitIsMadeAndAppearsInTheList() throws {
        let app = launchOnHabits()
        startAdding(app, kind: "kind-counted")
        type("Stretch", into: app.textFields["habitName"])
        XCTAssertEqual(app.staticTexts["targetValue"].label, "3 times a day")
        app.buttons["saveHabit"].tap()
        let stretch = row("Stretch", in: app)
        XCTAssertTrue(stretch.waitForExistence(timeout: 10))
        XCTAssertTrue(stretch.label.contains("Counted · 0 of 3 today"))
    }

    @MainActor
    func testAPresetFillsTheFormAndSaves() throws {
        let app = launchOnHabits()
        let add = app.buttons["addHabit"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let preset = app.buttons["preset-quran"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        preset.tap()
        XCTAssertEqual(app.textFields["habitName"].value as? String, "Qur'an reading")
        XCTAssertEqual(app.staticTexts["targetValue"].label, "15 minutes")
        app.buttons["saveHabit"].tap()
        XCTAssertTrue(row("Qur'an reading", in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testASaveWithoutANameSaysSoCalmly() throws {
        let app = launchOnHabits()
        startAdding(app, kind: "kind-binary")
        XCTAssertTrue(app.textFields["habitName"].waitForExistence(timeout: 5))
        app.buttons["saveHabit"].tap()
        XCTAssertTrue(app.staticTexts["Give it a name first."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSeveralTimesADayAreNamedAndShownInTheStatus() throws {
        let app = launchOnHabits()
        startAdding(app, kind: "kind-binary")
        type("Medication", into: app.textFields["habitName"])
        app.buttons["addWindow"].tap()
        XCTAssertTrue(app.buttons["window-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["window-1"].label.contains("Evening"))
        app.buttons["saveHabit"].tap()
        let medication = row("Medication", in: app)
        XCTAssertTrue(medication.waitForExistence(timeout: 10))
        XCTAssertTrue(medication.label.contains("morning at 06:00"), medication.label)
    }

    @MainActor
    func testPickingDaysAndAWeeklyTargetAreOffered() throws {
        let app = launchOnHabits()
        startAdding(app, kind: "kind-timed")
        type("Run", into: app.textFields["habitName"])
        app.buttons["scheduleWeekly"].tap()
        XCTAssertTrue(app.steppers.matching(NSPredicate(format: "label CONTAINS '3 times a week'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["schedulePick"].tap()
        XCTAssertTrue(app.buttons["Monday"].waitForExistence(timeout: 5))
        app.buttons["saveHabit"].tap()
        XCTAssertTrue(row("Run", in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testANewGroupCanBeMadeFromTheForm() throws {
        let app = launchOnHabits()
        startAdding(app, kind: "kind-binary")
        type("Stretch", into: app.textFields["habitName"])
        let chip = app.buttons["newGroupChip"]
        for _ in 0..<4 where !(chip.exists && chip.isHittable) { app.swipeUp() }
        chip.tap()
        type("Morning", into: app.textFields["newGroupName"])
        app.buttons["saveHabit"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Morning'")).firstMatch.waitForExistence(timeout: 10))
    }

    @MainActor
    func testEditingKeepsTheKindFixedAndSavesTheNewName() throws {
        let app = launchOnHabits(sample: true)
        row("Water", in: app).tap()
        app.buttons["habitMenu"].tap()
        app.buttons["Edit habit…"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'fixed'")).firstMatch.waitForExistence(timeout: 5))
        let name = app.textFields["habitName"]
        name.tap()
        name.typeText(", glasses")
        app.buttons["saveHabit"].tap()
        XCTAssertTrue(app.staticTexts["Water, glasses"].waitForExistence(timeout: 10))
    }
}
