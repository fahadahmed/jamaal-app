//
//  MacEnhancementsUITests.swift
//  JamaalMacUITests
//

import XCTest

/// The v1 enhancements on a real Mac: Day review in the detail column with ⌘[ and ⌘], Return to edit a task's title, and ⌘Z for the
/// undo toast. A Mac UI test drives the real desktop: keep your hands off the mouse and keyboard while it runs.
final class MacEnhancementsUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalPastDays", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"]
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
    func testCommandBracketsStepBetweenDaysInDayReview() throws {
        let app = launch()
        let yesterday = app.buttons["yesterdayRow"]
        XCTAssertTrue(yesterday.waitForExistence(timeout: 15))
        yesterday.click()
        let date = app.staticTexts["dayReviewDate"]
        XCTAssertTrue(date.waitForExistence(timeout: 10))
        // A Mac exposes a static text's string as its value rather than its label.
        func shown() -> String { (date.value as? String) ?? date.label }
        let start = shown()
        XCTAssertFalse(start.isEmpty, "the date is read")
        app.typeKey("[", modifierFlags: .command)
        let earlier = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", start), object: date)
        XCTAssertEqual(XCTWaiter().wait(for: [earlier], timeout: 5), .completed, "⌘[ goes to the day before")
        app.typeKey("]", modifierFlags: .command)
        let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", start), object: date)
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 5), .completed, "⌘] comes back")
    }

    @MainActor
    func testReturnOnASelectedTaskStartsEditingItsTitle() throws {
        let app = launch()
        let task = row("Reply to Sam", in: app)
        XCTAssertTrue(task.waitForExistence(timeout: 15))
        task.click()
        let title = app.descendants(matching: .any)["detailTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        app.typeKey(.return, modifierFlags: [])
        app.typeKey("a", modifierFlags: .command)                                  // select all of the title, if the field has focus
        app.typeText("Reply to Sam today")
        app.typeKey(.return, modifierFlags: [])
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Reply to Sam today'"), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 8), .completed, "Return put the cursor in the title")
    }

    @MainActor
    func testCommandZUndoesAnEditWhileTheToastIsUp() throws {
        let app = launch()
        let task = row("Call the clinic back", in: app)
        XCTAssertTrue(task.waitForExistence(timeout: 15))
        task.click()
        let effort = app.buttons["detailRow-Effort"]
        XCTAssertTrue(effort.waitForExistence(timeout: 10))
        effort.click()
        let option = app.buttons["effort-45"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.click()
        // Pick another task: leaving the edited one ends the visit and raises the toast.
        row("Reply to Sam", in: app).click()
        XCTAssertTrue(app.buttons["editUndoButton"].waitForExistence(timeout: 5))
        app.typeKey("z", modifierFlags: .command)
        row("Call the clinic back", in: app).click()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS '15 min'"), object: app.buttons["detailRow-Effort"])
        XCTAssertEqual(XCTWaiter().wait(for: [restored], timeout: 8), .completed, "⌘Z put it back")
    }
}
