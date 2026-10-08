//
//  IPadDetailUITests.swift
//  JamaalUITests
//

import XCTest

/// Habits and Anchors as list + detail panes on an iPad (iPad-HB-02): the picked item's detail beside the list, in a readable
/// column, with no back button. They run on an iPad simulator and skip on a phone (where a detail is pushed).
final class IPadDetailUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "regular width only")
    }

    @MainActor
    private func launch(_ args: [String], landscape: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalFakePlaces"] + args
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func openSidebarItem(_ title: String, in app: XCUIApplication) {
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), title)
        item.tap()
    }

    @MainActor
    private func row(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    // MARK: Habits

    @MainActor
    func testHabitsStartWithAPlaceholderBesideTheList() throws {
        let app = launch(["-JamaalSampleData"])
        openSidebarItem("Habits", in: app)
        XCTAssertTrue(element("habitPlaceholder", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(row("Floss", in: app).exists)
    }

    @MainActor
    func testPickingAHabitOpensItsDetailBesideTheListWithNoBackButton() throws {
        let app = launch(["-JamaalSampleData"])
        openSidebarItem("Habits", in: app)
        let floss = row("Floss", in: app)
        XCTAssertTrue(floss.waitForExistence(timeout: 8))
        floss.tap()
        let menu = element("habitMenu", in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        XCTAssertFalse(element("habitPlaceholder", in: app).exists)
        XCTAssertFalse(app.buttons["Back"].exists, "nothing was pushed, so there is nothing to go back from")
        XCTAssertGreaterThan(menu.frame.minX, floss.frame.maxX, "the detail is beside the list, not over it")
        XCTAssertTrue(row("Water", in: app).exists, "the list is still there")
    }

    @MainActor
    func testPickingAnotherHabitSwapsTheDetail() throws {
        let app = launch(["-JamaalSampleData"])
        openSidebarItem("Habits", in: app)
        row("Floss", in: app).tap()
        XCTAssertTrue(element("habitMenu", in: app).waitForExistence(timeout: 8))
        row("Water", in: app).tap()
        XCTAssertTrue(element("habitMenu", in: app).exists, "a detail is still open")
        XCTAssertFalse(element("habitPlaceholder", in: app).exists)
    }

    @MainActor
    func testArchivingFromTheDetailClearsThePane() throws {
        let app = launch(["-JamaalSampleData"])
        openSidebarItem("Habits", in: app)
        row("Floss", in: app).tap()
        let menu = element("habitMenu", in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(element("habitPlaceholder", in: app).waitForExistence(timeout: 8))
    }

    // MARK: Anchors

    @MainActor
    func testAnAnchorRuleOpensBesideTheListAsAReadableColumn() throws {
        let app = launch(["-JamaalAnchorRules"])
        openSidebarItem("Anchors", in: app)
        XCTAssertTrue(element("anchorPlaceholder", in: app).waitForExistence(timeout: 8))
        let rule = row("School run", in: app)
        XCTAssertTrue(rule.waitForExistence(timeout: 8))
        rule.tap()
        let menu = element("ruleMenu", in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        XCTAssertFalse(element("anchorPlaceholder", in: app).exists)
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertGreaterThan(menu.frame.minX, rule.frame.maxX, "the detail is beside the list, not over it")
    }

    @MainActor
    func testARuleWithLittleToShowStillFillsItsPaneInPortrait() throws {
        // With the sample data the seeded rules need attention, so the detail has almost nothing in it. Portrait shows the
        // top tab bar, so go to Anchors in landscape (where the sidebar is open) and turn the iPad.
        let app = launch(["-JamaalSampleData", "-JamaalAnchorRules"])
        openSidebarItem("Anchors", in: app)
        XCTAssertTrue(element("addAnchorRule", in: app).waitForExistence(timeout: 8))
        XCUIDevice.shared.orientation = .portrait
        let rule = row("School run", in: app)
        XCTAssertTrue(rule.waitForExistence(timeout: 8))
        rule.tap()
        let menu = element("ruleMenu", in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        let summary = app.staticTexts["ruleSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(summary.frame.minX, rule.frame.maxX, "the detail is beside the list")
        XCTAssertLessThan(summary.frame.minX, menu.frame.minX, "its text starts at the left of the pane, not centred in it")
    }

    @MainActor
    func testArchivingARuleFromTheDetailClearsThePane() throws {
        let app = launch(["-JamaalAnchorRules"])
        openSidebarItem("Anchors", in: app)
        row("School run", in: app).tap()
        let menu = element("ruleMenu", in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(element("anchorPlaceholder", in: app).waitForExistence(timeout: 8))
    }
}
