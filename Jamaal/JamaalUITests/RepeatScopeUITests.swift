//
//  RepeatScopeUITests.swift
//  JamaalUITests
//

import XCTest

/// A repeating task asks once per visit whether a change is for this one or every one after (TK-07), and the morning card names the
/// tasks that were scheduled for today ahead of time.
final class RepeatScopeUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func open(_ title: String, in app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(title) row")
        row.tap()
    }

    @MainActor
    private func setEffort(_ id: String, in app: XCUIApplication) {
        app.buttons["detailRow-Effort"].tap()
        XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5))
        app.buttons[id].tap()
    }

    @MainActor
    func testAChangeToARepeatingTaskAsksOnceAndCancelLeavesItAsItWas() throws {
        let app = launch(["-JamaalRepeating"])
        open("Weekly review", in: app)
        setEffort("effort-45", in: app)
        XCTAssertTrue(app.buttons["scopeLater"].waitForExistence(timeout: 5), "it asks")
        XCTAssertTrue(app.staticTexts["Effort goes from 30 min to 45 min."].exists)
        app.buttons["scopeCancel"].tap()
        let row = app.buttons["detailRow-Effort"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("30 min"), "Cancel changes nothing: \(row.label)")
    }

    @MainActor
    func testEveryOneAfterChangesItAndASecondChangeInTheSameVisitDoesNotAskAgain() throws {
        let app = launch(["-JamaalRepeating"])
        open("Weekly review", in: app)
        setEffort("effort-45", in: app)
        app.buttons["scopeLater"].tap()
        let row = app.buttons["detailRow-Effort"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("45 min"), row.label)
        setEffort("effort-60", in: app)
        XCTAssertFalse(app.buttons["scopeLater"].waitForExistence(timeout: 2), "asked once per visit")
        XCTAssertTrue(app.buttons["detailRow-Effort"].label.contains("1h"), app.buttons["detailRow-Effort"].label)
    }

    @MainActor
    func testOnlyThisOneChangesTodaysAndLeavesTheSeriesAsItWas() throws {
        let app = launch(["-JamaalRepeating", "-JamaalComingUp"])
        open("Weekly review", in: app)
        setEffort("effort-45", in: app)
        app.buttons["scopeOnly"].tap()
        let row = app.buttons["detailRow-Effort"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("45 min"), row.label)
        XCTAssertTrue(app.buttons["detailRow-Repeats"].label.contains("Never"), "this occurrence stopped repeating")
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["editUndoButton"].waitForExistence(timeout: 5))
        // The series carries on, a week ahead, as it was: Coming up lists it at 30 min.
        let comingUp = app.buttons["comingUpRow"]
        for _ in 0..<8 where !comingUp.isHittable { app.swipeUp() }
        comingUp.tap()
        let next = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Weekly review'")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        let effort = app.buttons["detailRow-Effort"]
        XCTAssertTrue(effort.waitForExistence(timeout: 5))
        XCTAssertTrue(effort.label.contains("30 min"), "the series keeps its old effort: \(effort.label)")
        XCTAssertTrue(app.buttons["detailRow-Repeats"].label.contains("Weekly"), "and keeps repeating")
    }

    @MainActor
    func testTheMorningCardNamesTheTasksScheduledForToday() throws {
        let app = launch(["-JamaalMorning", "-JamaalScheduled"])
        XCTAssertTrue(app.otherElements["morningCard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No plan for today. 2 tasks are scheduled for it, so two minutes to confirm?"].exists)
        app.buttons["morningNotNow"].tap()
        XCTAssertTrue(app.staticTexts["Dentist forms"].waitForExistence(timeout: 5), "Not now leaves them on the list")
    }
}
