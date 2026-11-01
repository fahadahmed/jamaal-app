//
//  MacSubscriptionUITests.swift
//  JamaalMacUITests
//

import XCTest

/// The plans sheet on a real Mac (#363). It opened too short, because the Subscription screen's sheet had no Mac size (a sheet is as big
/// as its content's ideal size, and these screens are scroll views with none), which nothing on the iPhone or iPad could show.
/// A Mac UI test drives the real desktop: keep your hands off the mouse and keyboard while it runs.
final class MacSubscriptionUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalDayStartMinute", "0"] + extra
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// ⌘, opens the Settings window (#366); the Subscription pane is one of its toolbar buttons.
    @MainActor
    private func openSubscription(_ app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.windows["Capacity and day"].waitForExistence(timeout: 15), "the Settings window opens")
        let inToolbar = app.toolbars.buttons["Subscription"]
        (inToolbar.exists ? inToolbar : app.buttons["Subscription"]).click()
        XCTAssertTrue(app.windows["Subscription"].waitForExistence(timeout: 10), "on the Subscription pane")
    }

    /// The plans need room: both plans, the renewal wording and its links, the button, Restore and Not now, without scrolling.
    @MainActor
    func testTheSubscriptionPlansSheetIsTallEnoughForThePlans() throws {
        let app = launch(["-JamaalAccess", "trial:9"])
        openSubscription(app)
        element("seePlans", in: app).click()
        let subscribe = element("subscribe", in: app)
        XCTAssertTrue(subscribe.waitForExistence(timeout: 10))
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.exists)
        XCTAssertGreaterThanOrEqual(sheet.frame.height, 560, "the sheet opens at the page height, not a small box")
        XCTAssertTrue(sheet.frame.contains(subscribe.frame), "and the Subscribe button is inside the sheet, with no scrolling (button \(subscribe.frame), sheet \(sheet.frame))")
        let picture = XCTAttachment(screenshot: app.windows["Subscription"].screenshot()); picture.name = "plans-sheet"; picture.lifetime = .keepAlways; add(picture)
        let notNow = element("notNow", in: app)
        XCTAssertTrue(notNow.isHittable, "with Not now reachable")
        XCTAssertTrue(sheet.frame.contains(notNow.frame), "and inside the sheet too, under Subscribe (Not now \(notNow.frame), sheet \(sheet.frame))")
    }

    @MainActor
    func testSeePlansOpensTheSheetAndBackAgain() throws {
        let app = launch(["-JamaalAccess", "trial:9"])
        openSubscription(app)
        let seePlans = element("seePlans", in: app)
        XCTAssertTrue(seePlans.waitForExistence(timeout: 10))
        seePlans.click()
        XCTAssertTrue(element("subscribe", in: app).waitForExistence(timeout: 10), "the plans sheet is up")
        element("notNow", in: app).click()
        XCTAssertTrue(seePlans.waitForExistence(timeout: 5), "back on the Subscription screen")
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testABetaWithTestPurchasesOpensThePlans() throws {
        let app = launch(["-JamaalBeta"])
        openSubscription(app)
        let toggle = element("betaPurchaseTesting", in: app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.click()
        let seePlans = element("seePlans", in: app)
        XCTAssertTrue(seePlans.waitForExistence(timeout: 10))
        seePlans.click()
        XCTAssertTrue(element("subscribe", in: app).waitForExistence(timeout: 10), "the plans sheet is up")
    }
}
