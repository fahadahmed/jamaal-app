//
//  MacTodayUITests.swift
//  JamaalMacUITests
//

import XCTest

/// Today on a real Mac: ⌘N, the focus chip in the sidebar, and the right-click menu on a task.
/// A Mac UI test drives the real desktop: keep your hands off the mouse and keyboard while it runs.
final class MacTodayUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = ["-JamaalSampleData"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"] + extra
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func task(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @MainActor
    func testCommandNOpensTheAddPanelFromAnotherSection() throws {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "addButton").firstMatch.waitForExistence(timeout: 15))
        app.typeKey("2", modifierFlags: .command)                                          // Habits
        app.typeKey("n", modifierFlags: .command)                                          // New Task
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 10), "⌘N lands on Today with the Add form open")
    }

    /// The Add form's Category and Repeat rows are menus: on a Mac they have to open under a click and keep the choice.
    @MainActor
    func testTheAddFormsCategoryAndRepeatCanBeChosen() throws {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "addButton").firstMatch.waitForExistence(timeout: 15))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 10))

        let category = app.descendants(matching: .any).matching(identifier: "categoryRow").firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.click()
        let family = app.menuItems["Family"]
        XCTAssertTrue(family.waitForExistence(timeout: 5), "clicking the Category row opens its menu")
        family.click()
        XCTAssertTrue(category.label.contains("Family") || (category.value as? String)?.contains("Family") == true,
                      "the row shows the choice: \(category.label)")

        let repeating = app.descendants(matching: .any).matching(identifier: "repeatRow").firstMatch
        XCTAssertTrue(repeating.waitForExistence(timeout: 5))
        repeating.click()
        let daily = app.menuItems["Daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 5), "clicking the Repeat row opens its menu")
        daily.click()
        XCTAssertTrue(repeating.label.contains("Daily") || (repeating.value as? String)?.contains("Daily") == true,
                      "the row shows the choice: \(repeating.label)")
    }

    @MainActor
    func testTheFocusChipIsInTheSidebarWhileASessionRuns() throws {
        let app = launch(["-JamaalSampleData", "-JamaalBegin"])
        let chip = app.descendants(matching: .any).matching(identifier: "focusChip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        let sidebar = app.descendants(matching: .any).matching(identifier: "sidebar-today").firstMatch
        XCTAssertTrue(sidebar.exists)
        XCTAssertLessThan(chip.frame.maxX, app.windows.firstMatch.frame.midX, "the chip is in the sidebar, on the left")
    }

    @MainActor
    func testRightClickingATaskOffersItsMenu() throws {
        let app = launch()
        let clinic = task("Call the clinic back", in: app)
        XCTAssertTrue(clinic.waitForExistence(timeout: 15))
        clinic.rightClick()
        XCTAssertTrue(app.menuItems["Begin"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Open"].exists)
        XCTAssertTrue(app.menuItems["Mark done"].exists)
        XCTAssertTrue(app.menuItems["Drop"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testBeginFromTheMenuStartsTheTimer() throws {
        let app = launch()
        let clinic = task("Call the clinic back", in: app)
        XCTAssertTrue(clinic.waitForExistence(timeout: 15))
        clinic.rightClick()
        app.menuItems["Begin"].click()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "focusChip").firstMatch.waitForExistence(timeout: 10))
    }
}
