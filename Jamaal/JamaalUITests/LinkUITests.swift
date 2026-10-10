//
//  LinkUITests.swift
//  JamaalUITests
//

import XCTest

/// The `jamaal://` links a widget opens the app with. `-JamaalOpenURL` feeds one through the same handler as a tap
/// (the system's "Open in Jamaal?" confirmation for outside links can't be tapped in a test).
final class LinkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(link: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalOpenURL", link]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        return app
    }

    @MainActor
    func testThePlanLinkOpensNightPlanning() throws {
        let app = launch(link: "jamaal://plan")
        XCTAssertTrue(app.buttons["planContinue"].waitForExistence(timeout: 10), "Night Planning opens")
    }

    @MainActor
    func testTheTodayLinkJustShowsToday() throws {
        let app = launch(link: "jamaal://today")
        XCTAssertTrue(app.staticTexts["Call the clinic back"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["planContinue"].exists)
    }

    @MainActor
    func testALinkThatIsNotOursChangesNothing() throws {
        let app = launch(link: "jamaal://nowhere")
        XCTAssertTrue(app.staticTexts["Call the clinic back"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["planContinue"].exists)
    }
}
