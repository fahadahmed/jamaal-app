//
//  ExitNoticeUITests.swift
//  JamaalUITests
//

import XCTest

/// After a run that ended without the app leaving the screen, Today shows one gentle card (docs/architecture/observability.md).
final class ExitNoticeUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testTheCardOffersANoteAndDoesNotSayCrashed() {
        let app = launch(["-JamaalExitNotice"])
        let card = app.descendants(matching: .any)["exitNotice"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["exitNoticeSend"].exists)
        XCTAssertTrue(app.buttons["exitNoticeNotNow"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'crash'")).firstMatch.exists)
    }

    @MainActor
    func testNotNowPutsTheCardAway() {
        let app = launch(["-JamaalExitNotice"])
        XCTAssertTrue(app.buttons["exitNoticeNotNow"].waitForExistence(timeout: 10))
        app.buttons["exitNoticeNotNow"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["exitNotice"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testWithoutTheFlagThereIsNoCard() {
        let app = launch()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["exitNotice"].exists)
    }
}
