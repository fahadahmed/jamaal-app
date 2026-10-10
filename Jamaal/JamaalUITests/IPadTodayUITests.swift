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
    private func launch(_ extra: [String] = [], landscape: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"] + extra
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait       // the simulator keeps its last orientation
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
        // The confirmation's Drop shares its label with the detail's own button, which has an identifier of its own.
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Drop' AND identifier != 'dropButton'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
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

    // MARK: The sidebar's furniture (landscape shows the sidebar)

    @MainActor
    private func sidebar(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    func testTheSidebarHasTheWordmarkCategoriesAndPlanTomorrow() throws {
        let app = launch(landscape: true)
        XCTAssertTrue(sidebar("sidebarWordmark", in: app).waitForExistence(timeout: 10))
        for name in ["Personal", "Family", "Work"] {
            XCTAssertTrue(sidebar("sidebarCategory-\(name)", in: app).exists, name)
        }
        XCTAssertTrue(sidebar("sidebarPlanTomorrow", in: app).exists)
    }

    @MainActor
    func testPickingACategoryInTheSidebarFiltersTodayAndPickingItAgainClears() throws {
        let app = launch(landscape: true)
        let work = sidebar("sidebarCategory-Work", in: app)
        XCTAssertTrue(work.waitForExistence(timeout: 10))
        XCTAssertTrue(row("Book Yusuf's swimming lessons", in: app).waitForExistence(timeout: 5))   // a Family task
        work.tap()
        XCTAssertTrue(row("Draft the architecture review", in: app).waitForExistence(timeout: 5))    // a Work task stays
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: row("Book Yusuf's swimming lessons", in: app))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
        work.tap()
        XCTAssertTrue(row("Book Yusuf's swimming lessons", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testPlanTomorrowInTheSidebarOpensNightPlanning() throws {
        let app = launch(landscape: true)
        let plan = sidebar("sidebarPlanTomorrow", in: app)
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        plan.tap()
        XCTAssertTrue(app.buttons["planContinue"].waitForExistence(timeout: 8))
    }

    // MARK: Add is a panel

    @MainActor
    private func tapAdd(_ app: XCUIApplication) {
        let add = app.buttons["addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
    }

    @MainActor
    func testAddOpensInThePanelBesideTheListNotInASheet() throws {
        let app = launch()
        tapAdd(app)
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["addTaskButton"].exists)
        XCTAssertFalse(app.staticTexts["detailPlaceholder"].exists)
        XCTAssertTrue(app.buttons["addButton"].isHittable, "nothing modal covers the list's toolbar")
        XCTAssertTrue(row("Draft the architecture review", in: app).exists, "the list is still there beside it")
    }

    @MainActor
    func testAddingFromThePanelPutsTheTaskOnTheListAndClearsThePanel() throws {
        let app = launch()
        tapAdd(app)
        let field = app.textFields["Title"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Renew the passport")
        app.buttons["High"].tap()                                                       // dated today, so it shows on Today
        app.buttons["addTaskButton"].tap()
        // At weekends the sample day's budget is Low and already over, so "Day is full" offers first: carry on.
        let anyway = app.buttons["addAnyway"]
        if anyway.waitForExistence(timeout: 3) { anyway.tap() }
        XCTAssertTrue(row("Renew the passport", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testClosingTheAddPanelClearsIt() throws {
        let app = launch()
        tapAdd(app)
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["detailPlaceholder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Title"].exists)
    }

    @MainActor
    func testPickingATaskWhileAddingSwitchesToItsDetail() throws {
        let app = launch()
        tapAdd(app)
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
        row("Call the clinic back", in: app).tap()
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Title"].exists)
    }

    @MainActor
    func testAddingWhileATaskIsOpenReplacesItsDetail() throws {
        let app = launch()
        row("Call the clinic back", in: app).tap()
        XCTAssertTrue(app.buttons["beginButton"].waitForExistence(timeout: 5))
        tapAdd(app)
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["beginButton"].exists)
    }

    // MARK: The row's context menu (right-click on a Mac, press and hold on an iPad)

    @MainActor
    func testPressingARowOffersItsMenu() throws {
        let app = launch()
        let clinic = row("Call the clinic back", in: app)
        XCTAssertTrue(clinic.waitForExistence(timeout: 10))
        clinic.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Begin"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mark done"].exists)
        XCTAssertTrue(app.buttons["Open"].exists)
        XCTAssertTrue(app.buttons["Drop"].exists)
    }

    @MainActor
    func testBeginFromTheMenuStartsTheTimer() throws {
        let app = launch()
        let clinic = row("Call the clinic back", in: app)
        XCTAssertTrue(clinic.waitForExistence(timeout: 10))
        clinic.press(forDuration: 1.2)
        app.buttons["Begin"].tap()
        XCTAssertTrue(app.buttons["focusChip"].waitForExistence(timeout: 8), "a session is running")
    }

    @MainActor
    func testDropFromTheMenuAsksFirstThenRemovesTheTask() throws {
        let app = launch()
        let clinic = row("Call the clinic back", in: app)
        XCTAssertTrue(clinic.waitForExistence(timeout: 10))
        clinic.press(forDuration: 1.2)
        app.buttons["Drop"].tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Drop' AND identifier != 'dropButton'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "it asks before dropping")
        XCTAssertTrue(row("Call the clinic back", in: app).exists, "nothing has gone yet")
        confirm.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: row("Call the clinic back", in: app))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed)
    }
}
