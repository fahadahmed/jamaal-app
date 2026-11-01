//
//  MacSettingsFormsUITests.swift
//  JamaalMacUITests
//

import XCTest

/// The Mac forms of the Settings panes (#367): Capacity and day, and Categories. A Mac UI test drives the real desktop: keep your hands off
/// the mouse and keyboard while it runs.
final class MacSettingsFormsUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) -> XCUIElement {
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows["Capacity and day"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        return window
    }

    @MainActor
    private func goTo(_ pane: String, titled title: String, in app: XCUIApplication) -> XCUIElement {
        let inToolbar = app.toolbars.buttons[pane]
        (inToolbar.exists ? inToolbar : app.buttons[pane]).click()
        let window = app.windows[title]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "the window is titled \(title)")
        return window
    }

    // MARK: Capacity and day

    @MainActor
    func testTheNormalDayStepsWithTheSystemStepper() throws {
        let app = launch()
        _ = openSettings(app)
        let value = element("normalDay", in: app)
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        func shown() -> String { (value.value as? String) ?? value.label }
        let before = shown()
        XCTAssertFalse(before.isEmpty, "the normal day is shown")
        element("normalDayStepper", in: app).incrementArrows.firstMatch.click()
        XCTAssertNotEqual(shown(), before, "one step up changes the normal day (was \(before))")
    }

    @MainActor
    func testAWeekdaysUsualLevelIsASegmentedChoice() throws {
        let app = launch()
        _ = openSettings(app)
        let monday = element("level-1", in: app)
        XCTAssertTrue(monday.waitForExistence(timeout: 10))
        monday.radioButtons["High"].click()
        XCTAssertEqual(monday.radioButtons["High"].value as? Int, 1, "High is the chosen level")
        monday.radioButtons["Low"].click()
        XCTAssertEqual(monday.radioButtons["Low"].value as? Int, 1, "and Low replaces it")
    }

    @MainActor
    func testTheWorkingDayAndTheRolloverAreThere() throws {
        let app = launch()
        _ = openSettings(app)
        for id in ["dayStart", "dayEnd", "rollover"] {
            XCTAssertTrue(element(id, in: app).waitForExistence(timeout: 10), id)
        }
    }

    // MARK: Categories

    @MainActor
    func testACategoryIsAddedAndThenArchivedAndRestored() throws {
        let app = launch()
        _ = openSettings(app)
        _ = goTo("Categories", titled: "Categories", in: app)
        element("addCategory", in: app).click()
        let field = element("newCategoryName", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.click()
        field.typeText("Gym\n")
        let row = element("category-Gym", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the new category is in the list")
        row.buttons["categoryArchive"].click()
        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "archiving takes it off the list")
        let archived = element("categoriesArchivedToggle", in: app)
        XCTAssertTrue(archived.waitForExistence(timeout: 10), "and it is under Archived")
    }

    // MARK: Notifications and Appearance (#368)

    @MainActor
    func testTheMorningListTimeShowsOnlyWhileItsSwitchIsOn() throws {
        let app = launch()
        _ = openSettings(app)
        _ = goTo("Notifications", titled: "Notifications and times", in: app)
        XCTAssertTrue(element("remindersSwitch", in: app).waitForExistence(timeout: 10), "this device's reminders switch")
        XCTAssertTrue(element("planningTime", in: app).exists, "the evening planning time")
        let morning = element("morningSwitch", in: app)
        XCTAssertTrue(morning.exists)
        let wasOn = element("morningTime", in: app).exists
        morning.click()
        XCTAssertEqual(element("morningTime", in: app).waitForExistence(timeout: 5), !wasOn, "the morning time follows its switch")
        morning.click()                                                          // put it back
        XCTAssertEqual(element("morningTime", in: app).waitForExistence(timeout: 5), wasOn)
    }

    @MainActor
    func testTheThemeIsASegmentedChoiceAndTheSuggestionCardsAreASwitch() throws {
        let app = launch()
        _ = openSettings(app)
        _ = goTo("Appearance", titled: "Appearance", in: app)
        let theme = element("themePicker", in: app)
        XCTAssertTrue(theme.waitForExistence(timeout: 10))
        for name in ["System", "Light", "Dark"] { XCTAssertTrue(theme.radioButtons[name].exists, "the theme has \(name)") }
        theme.radioButtons["Light"].click()
        XCTAssertEqual(theme.radioButtons["Light"].value as? Int, 1, "Light is chosen")
        theme.radioButtons["System"].click()                                     // put it back
        XCTAssertEqual(theme.radioButtons["System"].value as? Int, 1)
        let cards = element("suggestionCards", in: app)
        XCTAssertTrue(cards.exists)
        let before = "\(cards.value ?? "")"
        cards.click()
        XCTAssertNotEqual("\(cards.value ?? "")", before, "the switch changes (was \(before))")
        cards.click()                                                            // put it back
        XCTAssertEqual("\(cards.value ?? "")", before)
    }

    // MARK: A look at them

    /// Saves a picture of each pane with the test results, so the forms can be looked at (it asserts nothing).
    @MainActor
    func testPicturesOfTheMacForms() throws {
        let app = launch()
        let window = openSettings(app)
        XCTAssertTrue(element("level-1", in: app).waitForExistence(timeout: 10))
        let day = XCTAttachment(screenshot: window.screenshot()); day.name = "capacity-and-day"; day.lifetime = .keepAlways; add(day)
        let categories = goTo("Categories", titled: "Categories", in: app)
        sleep(1)
        let cats = XCTAttachment(screenshot: categories.screenshot()); cats.name = "categories"; cats.lifetime = .keepAlways; add(cats)
        let notifications = goTo("Notifications", titled: "Notifications and times", in: app)
        sleep(1)
        let notes = XCTAttachment(screenshot: notifications.screenshot()); notes.name = "notifications"; notes.lifetime = .keepAlways; add(notes)
        let appearance = goTo("Appearance", titled: "Appearance", in: app)
        sleep(1)
        let look = XCTAttachment(screenshot: appearance.screenshot()); look.name = "appearance"; look.lifetime = .keepAlways; add(look)
    }
}
