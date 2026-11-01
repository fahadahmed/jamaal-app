//
//  MacSettingsWindowUITests.swift
//  JamaalMacUITests
//

import XCTest

/// The Mac Settings window (#366): ⌘, opens a window of panes, a pane opens where the last one was left, and the main window has no
/// Settings of its own. A Mac UI test drives the real desktop: keep your hands off the mouse and keyboard while it runs.
final class MacSettingsWindowUITests: XCTestCase {

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
    func testCommandCommaOpensASettingsWindowWithAToolbarOfPanes() throws {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(element("macSettingsWindow", in: app).waitForExistence(timeout: 10), "⌘, opens the Settings window")
        for name in ["Day", "Notifications", "Categories", "Appearance", "Subscription", "iCloud", "Privacy"] {
            XCTAssertTrue(app.toolbars.buttons[name].exists || app.buttons[name].exists, "the toolbar has \(name)")
        }
    }

    @MainActor
    func testTheWindowOpensWhereItWasLeft() throws {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(element("macSettingsWindow", in: app).waitForExistence(timeout: 10))
        let subscription = app.toolbars.buttons["Subscription"].exists ? app.toolbars.buttons["Subscription"] : app.buttons["Subscription"]
        subscription.click()
        XCTAssertTrue(element("subscriptionLabel", in: app).waitForExistence(timeout: 10), "the Subscription pane")
        app.typeKey("w", modifierFlags: .command)                                  // close the Settings window
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(element("subscriptionLabel", in: app).waitForExistence(timeout: 10), "and it comes back to the Subscription pane")
    }
}
