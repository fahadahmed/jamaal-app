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

    /// The Settings window is the one titled with a pane's full name (the window's title follows the pane, as the HIG asks).
    @MainActor
    private func settingsWindow(_ title: String, in app: XCUIApplication) -> XCUIElement { app.windows[title] }

    @MainActor
    private func paneButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let inToolbar = app.toolbars.buttons[name]
        return inToolbar.exists ? inToolbar : app.buttons[name]
    }

    @MainActor
    func testCommandCommaOpensASettingsWindowWithAToolbarOfPanes() throws {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        let window = settingsWindow("Capacity and day", in: app)
        XCTAssertTrue(window.waitForExistence(timeout: 10), "⌘, opens the Settings window, at the first pane, titled with its name")
        let missing = ["Day", "Notifications", "Categories", "Appearance", "Subscription", "iCloud", "Privacy"].filter { !paneButton($0, in: app).exists }
        XCTAssertTrue(missing.isEmpty, "the toolbar has a button for every pane; missing \(missing). Buttons: \(app.toolbars.buttons.allElementsBoundByIndex.map(\.title))")
    }

    @MainActor
    func testTheWindowOpensWhereItWasLeft() throws {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsWindow("Capacity and day", in: app).waitForExistence(timeout: 10))
        paneButton("Subscription", in: app).click()
        XCTAssertTrue(settingsWindow("Subscription", in: app).waitForExistence(timeout: 10), "the window is now titled with the pane")
        XCTAssertTrue(element("subscriptionLabel", in: app).waitForExistence(timeout: 10), "and shows the Subscription pane")
        app.typeKey("w", modifierFlags: .command)                                  // close the Settings window
        XCTAssertTrue(app.windows["Subscription"].waitForNonExistence(timeout: 5))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsWindow("Subscription", in: app).waitForExistence(timeout: 10), "and it comes back to the Subscription pane")
    }
}
