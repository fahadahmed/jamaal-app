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

    /// A segmented picker shows its own label on the Mac, and the row had a `Text` with the day as well, so each day was named twice (#371).
    @MainActor
    func testEachWeekdayIsNamedOnceInCapacityAndDay() throws {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        let window = settingsWindow("Capacity and day", in: app)
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(element("level-1", in: app).waitForExistence(timeout: 10), "the weekday rows are there")
        // The visible text carrying each day's name. (The picker's own accessibility name, a radio group, is not visible text and stays.)
        func texts(_ day: String) -> [XCUIElement] {
            window.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@ OR title == %@", day, day, day)).allElementsBoundByIndex
        }
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let notOnce = days.filter { texts($0).count != 1 }
        let report = days.map { day in "\(day): \(texts(day).count)" }
        XCTAssertTrue(notOnce.isEmpty, "each weekday is written once; not once: \(notOnce) (\(report))")
    }

    /// The calm locked sheet needs room under its buttons on the Mac (#371).
    @MainActor
    func testTheLockedSheetLeavesRoomBelowItsButtons() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalDayStartMinute", "0", "-JamaalAccess", "readOnly"]
        app.launch()
        app.activate()
        XCTAssertTrue(element("notNow", in: app).waitForExistence(timeout: 20), "the paywall opens first when the trial has ended")
        element("notNow", in: app).click()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(settingsWindow("Capacity and day", in: app).waitForExistence(timeout: 10))
        paneButton("Categories", in: app).click()
        let add = element("addCategory", in: app)
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.click()                                                            // adding needs a subscription: the locked sheet
        let notNow = element("lockedNotNow", in: app)
        XCTAssertTrue(notNow.waitForExistence(timeout: 10), "the locked sheet is up")
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.exists)
        let room = sheet.frame.maxY - notNow.frame.maxY
        XCTAssertGreaterThanOrEqual(room, 16, "there is room under the buttons (\(Int(room)) pt)")
    }
}
