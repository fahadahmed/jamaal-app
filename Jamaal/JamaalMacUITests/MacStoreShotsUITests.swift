//
//  MacStoreShotsUITests.swift
//  JamaalMacUITests
//

import XCTest

/// Takes the raw App Store pictures of the Mac app (#362): the store dataset, Light, the window at a fixed size, a picture of the window
/// (and of the Settings window) attached to the results under the name the handoff expects. It only runs when asked
/// (`JAMAAL_STORE_SHOTS=1`, which `assets/appstore/capture-mac.sh` sets). It drives the real desktop: keep your hands off the mouse.
final class MacStoreShotsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["JAMAAL_STORE_SHOTS"] == "1", "only when making the store pictures")
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalStoreShots", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium",
                               "-JamaalTheme", "light", "-JamaalMacWindow", "1280x780", "-ApplePersistenceIgnoreState", "YES"] + extra
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30), "the app's window opens with \(extra)")
        sleep(6)
        return app
    }

    private func picture(_ element: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func shot(_ name: String, _ extra: [String] = []) {
        let app = launch(extra)
        picture(app.windows.firstMatch, name)
        app.terminate()
        sleep(2)
    }

    @MainActor func testToday() { shot("1-today-open", ["-JamaalWellbeing", "steady", "-JamaalOpenTask"]) }
    /// Opened the way a person does (⇧⌘P), then on to the Build step (a launch argument can't open the Mac's sheet).
    @MainActor
    func testNightPlanning() {
        let app = launch(["-JamaalEvening"])
        app.typeKey("p", modifierFlags: [.command, .shift])
        let next = app.buttons["planContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 15), "Night Planning opens")
        for _ in 0..<2 {                                                                // Review, then Carry forward, then Build
            next.click()
            sleep(2)
        }
        picture(app.windows.firstMatch, "2-night-build")
        app.terminate()
    }
    @MainActor func testHabits() { shot("3-habits-open", ["-JamaalTab", "habits", "-JamaalOpenHabit"]) }
    @MainActor func testAnchors() { shot("4-anchors-open", ["-JamaalTab", "anchors", "-JamaalOpenRule", "-JamaalAnchorRules"]) }
    @MainActor func testWellbeing() { shot("5-wellbeing", ["-JamaalTab", "wellbeing", "-JamaalWellbeing", "steady"]) }
    @MainActor func testFocus() { shot("6-focus", ["-JamaalBegin", "-JamaalOpenFocus"]) }

    @MainActor
    func testSettings() {
        let app = launch(["-JamaalWellbeing", "steady"])
        app.typeKey(",", modifierFlags: .command)                                      // the Settings window, on its first pane
        let settings = app.windows["Capacity and day"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15), "the Settings window opens; windows: \(app.windows.allElementsBoundByIndex.map(\.title))")
        sleep(2)
        picture(settings, "7-settings-day")
        app.terminate()
    }
}
