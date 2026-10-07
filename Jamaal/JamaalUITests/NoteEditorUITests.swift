//
//  NoteEditorUITests.swift
//  JamaalUITests
//

import XCTest

/// Writing a task's note: the editor, its toolbar, and Return keeping a checklist going.
final class NoteEditorUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func open(_ title: String, in app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        for _ in 0..<5 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(title) row")
        row.tap()
    }

    @MainActor
    private func editor(_ app: XCUIApplication) -> XCUIElement {
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        return editor
    }

    @MainActor
    private func openEditorOnSwimming(_ app: XCUIApplication) -> XCUIElement {
        open("Book Yusuf's swimming lessons", in: app)
        let add = app.buttons["editNote"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertEqual(add.label, "Add a note")
        add.tap()
        return editor(app)
    }

    @MainActor
    func testANoteIsWrittenAsAChecklistAndTickedFromTheDetail() throws {
        let app = launch()
        let text = openEditorOnSwimming(app)
        text.typeText("Ask the price")
        app.buttons["noteChecklist"].tap()
        XCTAssertEqual(text.value as? String, "- [ ] Ask the price")
        app.buttons["noteDone"].tap()
        let item = app.buttons["Ask the price"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertEqual(item.value as? String, "Not done")
        item.tap()
        XCTAssertEqual(app.buttons["Ask the price"].value as? String, "Done")
        XCTAssertEqual(app.buttons["editNote"].label, "Edit note")
    }

    /// Waits for the editor's text to become `expected` (Return's list continuation settles a moment after the key).
    @MainActor
    private func waitForText(_ expected: String, in text: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: text)
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 5), .completed, "was \(String(describing: text.value))", file: file, line: line)
    }

    @MainActor
    func testReturnKeepsAChecklistGoingAndAnEmptyItemEndsIt() throws {
        let app = launch()
        let text = openEditorOnSwimming(app)
        app.buttons["noteChecklist"].tap()
        text.typeText("One\n")
        waitForText("- [ ] One\n- [ ] ", in: text)
        text.typeText("Two\n")
        waitForText("- [ ] One\n- [ ] Two\n- [ ] ", in: text)
        text.typeText("\n")                                                       // Return on the empty item ends the list
        waitForText("- [ ] One\n- [ ] Two\n", in: text)
    }

    @MainActor
    func testBoldPlacesTheMarkersAndTheCaretBetweenThem() throws {
        let app = launch()
        let text = openEditorOnSwimming(app)
        text.typeText("Call ")
        app.buttons["noteBold"].tap()
        text.typeText("now")
        XCTAssertEqual(text.value as? String, "Call **now**")
    }

    @MainActor
    func testALinkStartsWithTheAddressSelectedToTypeOver() throws {
        let app = launch()
        let text = openEditorOnSwimming(app)
        app.buttons["noteLink"].tap()
        text.typeText("example.com")
        XCTAssertEqual(text.value as? String, "[link](example.com)")
    }

    @MainActor
    func testAnExistingNoteOpensForEditingAndWhatIsWrittenSavesWithoutDone() throws {
        let app = launch()
        open("Call the clinic back", in: app)
        let edit = app.buttons["editNote"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        XCTAssertEqual(edit.label, "Edit note")
        edit.tap()
        let text = editor(app)
        XCTAssertTrue((text.value as? String ?? "").contains("referral"))
        text.typeText(" extra")
        app.buttons["noteBack"].tap()                                              // Back keeps it, like Done
        XCTAssertTrue(app.buttons["editNote"].waitForExistence(timeout: 5))
        app.buttons["editNote"].tap()
        XCTAssertTrue((editor(app).value as? String ?? "").hasSuffix(" extra"))
    }

    @MainActor
    func testEmptyingTheNoteTakesItAwayFromTheDetail() throws {
        let app = launch()
        let text = openEditorOnSwimming(app)
        text.typeText("Temp")
        app.buttons["noteChecklist"].tap()
        app.buttons["noteDone"].tap()
        XCTAssertTrue(app.buttons["Temp"].waitForExistence(timeout: 5))
        app.buttons["editNote"].tap()
        let again = editor(app)
        again.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        app.buttons["noteDone"].tap()
        XCTAssertTrue(app.buttons["editNote"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["editNote"].label, "Add a note")
        XCTAssertFalse(app.buttons["Temp"].exists)
    }

    @MainActor
    func testWhenReadOnlyWritingANoteOpensTheCalmSheetNotTheEditor() throws {
        let app = launch(["-JamaalAccess", "readOnly"])
        XCTAssertTrue(app.buttons["notNow"].waitForExistence(timeout: 10))
        app.buttons["notNow"].tap()
        open("Book Yusuf's swimming lessons", in: app)
        let add = app.buttons["editNote"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.descendants(matching: .any)["lockedSheet"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["noteEditor"].exists)
    }
}
