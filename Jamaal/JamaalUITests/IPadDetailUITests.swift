//
//  IPadDetailUITests.swift
//  JamaalUITests
//

import XCTest

/// The pushed Anchor rule and Habit details on an iPad: a readable column, not edge to edge and not shrunk to its content.
/// They run on an iPad simulator and skip on a phone.
final class IPadDetailUITests: XCTestCase {

    /// The column's width (720 pt) plus a little for the buttons' own padding.
    private let column: ClosedRange<CGFloat> = 600...760

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "regular width only")
    }

    @MainActor
    private func launch(_ args: [String], landscape: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalFakePlaces"] + args
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        app.launch()
        return app
    }

    /// The sidebar is open in landscape (in portrait the top tab bar leaves Anchors out), so navigate there.
    @MainActor
    private func openSidebarItem(_ title: String, in app: XCUIApplication) {
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), title)
        item.tap()
    }

    /// The span between the Back button and the Edit menu is the top bar's width: the column's.
    @MainActor
    private func assertColumn(menu: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let back = app.buttons["Back"]
        let edit = app.descendants(matching: .any).matching(identifier: menu).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 8), "no Back button", file: file, line: line)
        XCTAssertTrue(edit.exists, "no \(menu) menu", file: file, line: line)
        let span = edit.frame.maxX - back.frame.minX
        XCTAssertTrue(column.contains(span), "the top bar spans \(span) pt, not a ~720 pt column", file: file, line: line)
    }

    @MainActor
    func testAnAnchorRuleDetailIsAReadableColumnInLandscape() throws {
        let app = launch(["-JamaalAnchorRules"], landscape: true)
        openSidebarItem("Anchors", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'School run'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
        assertColumn(menu: "ruleMenu", in: app)
    }

    @MainActor
    func testARuleWithLittleToShowStillFillsTheColumnInPortrait() throws {
        // With the sample data the seeded rules need attention, so the detail has almost nothing in it.
        let app = launch(["-JamaalSampleData", "-JamaalAnchorRules"], landscape: true)
        openSidebarItem("Anchors", in: app)
        XCTAssertTrue(app.buttons["addAnchorRule"].waitForExistence(timeout: 8), "didn't reach the Anchors list")
        XCUIDevice.shared.orientation = .portrait
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'School run'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
        assertColumn(menu: "ruleMenu", in: app)
        let summary = app.staticTexts["ruleSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertLessThan(summary.frame.minX, app.buttons["Back"].frame.minX + 40, "the text is left-aligned in the column, not centred in it")
    }

    @MainActor
    func testAHabitDetailIsAReadableColumnInLandscape() throws {
        let app = launch(["-JamaalSampleData"], landscape: true)
        openSidebarItem("Habits", in: app)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Floss'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
        assertColumn(menu: "habitMenu", in: app)
    }
}
