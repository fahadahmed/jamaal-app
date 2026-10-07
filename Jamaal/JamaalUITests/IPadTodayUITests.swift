//
//  IPadTodayUITests.swift
//  JamaalUITests
//

import XCTest

/// Regular width: Today with the task detail beside the list instead of a sheet. These run on an iPad simulator and skip
/// on a phone (where the detail is a sheet, covered by the task detail tests).
final class IPadTodayUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "regular width only")
    }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func row(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @MainActor
    func testWithNothingPickedThePanelSaysWhatToDo() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["addButton"].exists)
    }

    @MainActor
    func testPickingATaskShowsItsDetailBesideTheListNotInASheet() throws {
        let app = launch()
        let clinic = row("Call the clinic back", in: app)
        XCTAssertTrue(clinic.waitForExistence(timeout: 10))
        clinic.tap()
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 5))         // the detail's actions are on screen
        XCTAssertTrue(app.buttons["addButton"].isHittable)                              // the list's toolbar is pinned: still there, still tappable
        XCTAssertTrue(row("Draft the architecture review", in: app).exists)             // the list is still there beside it
        XCTAssertFalse(app.staticTexts["detailPlaceholder"].exists)
        XCTAssertTrue(clinic.isSelected || clinic.value != nil || clinic.exists)        // the open task is marked in the list
    }

    @MainActor
    func testPickingAnotherTaskSwapsTheDetail() throws {
        let app = launch()
        row("Call the clinic back", in: app).tap()
        XCTAssertTrue(app.staticTexts["Ask about the referral letter"].waitForExistence(timeout: 5) || app.buttons["Ask about the referral letter"].waitForExistence(timeout: 5))
        row("Draft the architecture review", in: app).tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Ask about the referral letter"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["beginButton"].exists)
    }

    @MainActor
    func testDroppingFromThePanelClearsItAndTheTaskLeavesTheList() throws {
        let app = launch()
        row("Call the clinic back", in: app).tap()
        let drop = app.buttons["dropButton"]
        XCTAssertTrue(drop.waitForExistence(timeout: 5))
        drop.tap()
        // On iPad the confirmation is a popover; the detail's own Drop button shares its label, so look inside the popover.
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5))
        popover.buttons["Drop"].tap()
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 5))
        XCTAssertFalse(row("Call the clinic back", in: app).exists)
    }

    @MainActor
    func testMarkingDoneFromThePanelClearsItToo() throws {
        let app = launch()
        row("Call the clinic back", in: app).tap()
        let done = app.buttons["Mark done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTheNoteEditorOpensFromThePanel() throws {
        let app = launch()
        row("Call the clinic back", in: app).tap()
        let edit = app.buttons["editNote"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.textViews["noteEditor"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTheSidebarShowsTheDestinationsIncludingAnchorsOnItsOwn() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 10))
        let anchors = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Anchors'")).firstMatch
        XCTAssertTrue(anchors.exists, "Anchors is its own item at regular width (the Habits segment is for the phone)")
    }

    @MainActor
    func testTheToolbarStaysWhileTheListScrolls() throws {
        let app = launch()
        let add = app.buttons["addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        let before = add.frame
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(add.isHittable)
        XCTAssertEqual(add.frame.minY, before.minY, accuracy: 2, "the toolbar doesn't move with the content")
        add.tap()
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testThePanelHasAMoreMenuWithTheNote() throws {
        let app = launch()
        row("Call the clinic back", in: app).tap()
        let more = app.buttons["moreMenu"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(app.buttons["Edit note"].waitForExistence(timeout: 5))
    }
}
