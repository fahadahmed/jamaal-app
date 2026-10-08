//
//  IPadSettingsUITests.swift
//  JamaalUITests
//

import XCTest

/// Settings as a list + detail pane on an iPad: the picked section's screen beside the list, with no back button. They run
/// on an iPad simulator and skip on a phone (where each section is pushed; see the Settings tab tests).
final class IPadSettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "regular width only")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Settings'")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        item.tap()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    func testSettingsStartWithAPlaceholderBesideTheList() throws {
        let app = launch()
        XCTAssertTrue(element("settingsPlaceholder", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("settings-capacity", in: app).exists)
    }

    @MainActor
    func testPickingASectionShowsItsScreenBesideTheListWithNoBackButton() throws {
        let app = launch()
        let row = element("settings-capacity", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
        let normalDay = element("normalDay", in: app)
        XCTAssertTrue(normalDay.waitForExistence(timeout: 8))
        XCTAssertFalse(element("settingsPlaceholder", in: app).exists)
        XCTAssertFalse(app.buttons["Back"].exists, "nothing was pushed")
        XCTAssertGreaterThan(normalDay.frame.minX, row.frame.maxX, "the screen is beside the list, not over it")
        XCTAssertTrue(element("settings-appearance", in: app).exists, "the list is still there")
    }

    @MainActor
    func testPickingAnotherSectionSwapsTheScreen() throws {
        let app = launch()
        element("settings-capacity", in: app).tap()
        XCTAssertTrue(element("normalDay", in: app).waitForExistence(timeout: 8))
        element("settings-appearance", in: app).tap()
        XCTAssertTrue(app.segmentedControls["themePicker"].waitForExistence(timeout: 8))
        XCTAssertFalse(element("normalDay", in: app).exists)
    }
}
