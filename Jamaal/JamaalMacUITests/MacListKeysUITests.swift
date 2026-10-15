//
//  MacListKeysUITests.swift
//  JamaalMacUITests
//

import XCTest

/// Today's list from the keyboard on a real Mac: ↓ and ↑ move the selection (the task in the panel), Space marks it
/// done, Delete asks to drop it. A Mac UI test drives the real desktop: keep your hands off the mouse and keyboard.
final class MacListKeysUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        app.activate()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        return app
    }

    @MainActor
    private func row(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @MainActor
    private func panelTitle(_ app: XCUIApplication) -> String {
        let title = app.staticTexts["detailTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "a task is open in the panel")
        return title.label
    }

    @MainActor
    func testTheArrowKeysMoveTheSelectionDownAndBackUp() throws {
        let app = launch()
        let first = row("Draft the architecture review", in: app)                         // the first task in Today's order: ↓ has somewhere to go
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.click()
        let start = panelTitle(app)
        XCTAssertEqual(start, "Draft the architecture review")

        app.typeKey(.downArrow, modifierFlags: [])
        let moved = panelTitle(app)
        XCTAssertNotEqual(moved, start, "↓ selects the next task")

        app.typeKey(.upArrow, modifierFlags: [])
        XCTAssertEqual(panelTitle(app), start, "↑ comes back")
    }

    @MainActor
    func testTheSelectionStopsAtTheLastTask() throws {
        let app = launch()
        let first = row("Reply to Sam", in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.click()
        var last = panelTitle(app)
        for _ in 0..<12 {                                                                  // more presses than tasks
            app.typeKey(.downArrow, modifierFlags: [])
            let now = panelTitle(app)
            if now == last { break }
            last = now
        }
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertEqual(panelTitle(app), last, "it stops at the end instead of wrapping")
    }

    @MainActor
    func testSpaceMarksTheSelectedTaskDone() throws {
        let app = launch()
        let reply = row("Reply to Sam", in: app)
        XCTAssertTrue(reply.waitForExistence(timeout: 15))
        reply.click()
        XCTAssertTrue(app.buttons["Mark Reply to Sam done"].exists)
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(app.buttons["Mark Reply to Sam not done"].waitForExistence(timeout: 5), "Space ticks it")
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(app.buttons["Mark Reply to Sam done"].waitForExistence(timeout: 5), "and again unticks it")
    }

    @MainActor
    func testDeleteAsksBeforeDropping() throws {
        let app = launch()
        let reply = row("Reply to Sam", in: app)
        XCTAssertTrue(reply.waitForExistence(timeout: 15))
        reply.click()
        app.typeKey(.delete, modifierFlags: [])
        // The confirmation's button, not the detail panel's own Drop button (identifier dropButton); a Mac may present it as a sheet or a dialog.
        let confirm = app.descendants(matching: .button).matching(NSPredicate(format: "label == 'Drop' AND identifier != 'dropButton'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete asks first")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(row("Reply to Sam", in: app).waitForExistence(timeout: 5), "cancelling keeps the task")
    }
}
