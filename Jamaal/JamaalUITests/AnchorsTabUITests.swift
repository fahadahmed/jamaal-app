//
//  AnchorsTabUITests.swift
//  JamaalUITests
//

import XCTest

/// The Anchors segment: the rules list, a rule's detail, making and editing a rule, breaks, and the one-off Anchor.
final class AnchorsTabUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(rules: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"] + (rules ? ["-JamaalAnchorRules"] : [])
        app.launch()
        let tab = app.tabBars.buttons["Habits"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let segment = app.segmentedControls.firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5))
        segment.buttons["Anchors"].tap()
        return app
    }

    @MainActor
    private func row(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    @MainActor
    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    @MainActor
    func testTheListShowsEachRulesScheduleAndState() throws {
        let app = launch(rules: true)
        let school = row("School run", in: app)
        XCTAssertTrue(school.waitForExistence(timeout: 10))
        XCTAssertTrue(school.label.contains("Mon–Fri · drop-off 08:15, pick-up 15:00"), school.label)
        XCTAssertTrue(row("Bin night", in: app).label.contains("Tuesdays · 19:00–22:00"))
        let plants = row("Water the plants", in: app)
        reveal(plants, in: app)
        XCTAssertTrue(plants.label.contains("3–4 days after last"), plants.label)
        let madrasa = row("Madrasa pick-up", in: app)
        reveal(madrasa, in: app)
        XCTAssertTrue(madrasa.label.contains("Paused · holiday · until"), madrasa.label)
        let swimming = row("Swimming club", in: app)
        reveal(swimming, in: app)
        XCTAssertTrue(swimming.label.contains("Needs attention · update Jamaal to see it"))
    }

    @MainActor
    func testTheArchiveListsARuleAndRestoreBringsItBack() throws {
        let app = launch(rules: true)
        let toggle = app.buttons["anchorsArchivedToggle"]
        reveal(toggle, in: app)
        toggle.tap()
        let restore = app.buttons["Restore Nursery drop-off"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        let restored = row("Nursery drop-off", in: app)
        reveal(restored, in: app)
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
    }

    @MainActor
    func testARulesDetailShowsItsScheduleAndWhatIsComingUp() throws {
        let app = launch(rules: true)
        row("School run", in: app).tap()
        XCTAssertTrue(app.staticTexts["SCHOOL RUN"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ruleSummary"].exists)
        XCTAssertTrue(app.staticTexts["Coming up"].exists || app.staticTexts["COMING UP"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(row("School run", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testABinNightRuleIsMadeFromItsPreset() throws {
        let app = launch(rules: false)
        let add = app.buttons["addAnchorRule"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let binNight = app.buttons["type-binNight"]
        XCTAssertTrue(binNight.waitForExistence(timeout: 5))
        binNight.tap()
        XCTAssertEqual(app.textFields["anchorName"].value as? String, "Bin night")
        app.buttons["saveAnchorRule"].tap()
        let made = row("Bin night", in: app)
        XCTAssertTrue(made.waitForExistence(timeout: 10))
        XCTAssertTrue(made.label.contains("Wednesdays"), made.label)
    }

    @MainActor
    func testACustomRuleNeedsDaysAndATimeAndSaysSoCalmly() throws {
        let app = launch(rules: false)
        app.buttons["addAnchorRule"].tap()
        let custom = app.buttons["type-custom"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        custom.tap()
        type("Choir", into: app.textFields["anchorName"])
        app.buttons["saveAnchorRule"].tap()
        XCTAssertTrue(app.staticTexts["Pick at least one day."].waitForExistence(timeout: 5))
        // The day circles are set in the label face, which capitalises their names.
        app.buttons.matching(NSPredicate(format: "label ==[c] 'Thursday'")).firstMatch.tap()
        app.buttons["saveAnchorRule"].tap()
        XCTAssertTrue(app.staticTexts["Add at least one time."].waitForExistence(timeout: 5))
        app.buttons["addSlot"].tap()
        app.buttons["saveAnchorRule"].tap()
        XCTAssertTrue(row("Choir", in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testABreakCanBeAddedToARuleAndRemoved() throws {
        let app = launch(rules: true)
        row("School run", in: app).tap()
        let add = app.buttons["addException"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let save = app.buttons["exceptionSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let exception = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Holiday ·'")).firstMatch
        XCTAssertTrue(exception.waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove Holiday'")).firstMatch.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: exception)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    @MainActor
    func testEditingARuleChangesItsName() throws {
        let app = launch(rules: true)
        row("Bin night", in: app).tap()
        app.buttons["ruleMenu"].tap()
        app.buttons["Edit rule…"].tap()
        let name = app.textFields["anchorName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" (green)")
        app.buttons["saveAnchorRule"].tap()
        XCTAssertTrue(app.staticTexts["Bin night (green)"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testArchivingFromTheDetailMovesItToTheArchive() throws {
        let app = launch(rules: true)
        row("Bin night", in: app).tap()
        app.buttons["ruleMenu"].tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["Anchors"].waitForExistence(timeout: 5))
        XCTAssertFalse(row("Bin night", in: app).exists)
    }

    @MainActor
    func testAOneOffAnchorIsAddedFromTheAddSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"]
        app.launch()
        let add = app.buttons["addButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let mode = app.segmentedControls["addMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.buttons["Anchor"].tap()
        type("Dentist", into: app.textFields["oneOffTitle"])
        app.buttons["Tomorrow"].tap()
        app.buttons["Add Anchor for tomorrow"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 10))
    }
}
