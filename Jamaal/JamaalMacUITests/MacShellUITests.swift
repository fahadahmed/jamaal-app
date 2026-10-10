//
//  MacShellUITests.swift
//  JamaalMacUITests
//

import XCTest

/// The Mac shell on a real Mac: the sidebar, and the menu bar's shortcuts (⌘1 to ⌘4, ⌘, and ⇧⌘P).
/// A Mac UI test drives the real desktop: keep your hands off the mouse and keyboard while it runs.
final class MacShellUITests: XCTestCase {

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
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    func testTheSidebarHasTheFourSectionsAndNoSettings() throws {
        let app = launch()
        XCTAssertTrue(element("sidebar-today", in: app).waitForExistence(timeout: 15))
        for id in ["sidebar-habits", "sidebar-anchors", "sidebar-wellbeing"] {
            XCTAssertTrue(element(id, in: app).exists, id)
        }
        XCTAssertFalse(element("sidebar-settings", in: app).exists, "on a Mac Settings is in the app menu, not the sidebar")
    }

    @MainActor
    func testTheSidebarHasItsWordmarkAndPlanTomorrow() throws {
        let app = launch()
        XCTAssertTrue(element("sidebarWordmark", in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(element("sidebarPlanTomorrow", in: app).exists)
    }

    @MainActor
    func testCommandNumbersGoToTheSections() throws {
        let app = launch(["-JamaalSampleData", "-JamaalAnchorRules"])
        XCTAssertTrue(element("addButton", in: app).waitForExistence(timeout: 15), "Today first")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(element("addHabit", in: app).waitForExistence(timeout: 8), "⌘2 is Habits")
        XCTAssertFalse(element("addButton", in: app).exists)

        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(element("addAnchorRule", in: app).waitForExistence(timeout: 8), "⌘3 is Anchors")

        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(element("addButton", in: app).waitForExistence(timeout: 8), "⌘1 is Today")
    }

    @MainActor
    func testCommandCommaOpensSettingsInTheMainWindow() throws {
        let app = launch()
        XCTAssertTrue(element("addButton", in: app).waitForExistence(timeout: 15))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(element("settings-capacity", in: app).waitForExistence(timeout: 8), "⌘, shows Settings")
    }

    @MainActor
    func testShiftCommandPOpensNightPlanning() throws {
        let app = launch()
        XCTAssertTrue(element("addButton", in: app).waitForExistence(timeout: 15))
        app.typeKey("p", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons["planContinue"].waitForExistence(timeout: 10), "⇧⌘P opens Night Planning")
    }

    @MainActor
    func testClickingACategoryInTheSidebarFiltersToday() throws {
        let app = launch()
        let work = element("sidebarCategory-Work", in: app)
        XCTAssertTrue(work.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Book Yusuf'")).firstMatch.waitForExistence(timeout: 8), "a Family task")
        work.click()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Book Yusuf'")).firstMatch)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed, "only Work tasks are left")
    }
}
