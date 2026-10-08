//
//  IPadPlanningUITests.swift
//  JamaalUITests
//

import XCTest

/// Night Planning's wide canvas (NP-07) on an iPad: the step rail beside the open step. They run on an iPad simulator and
/// skip on a phone, where the flow is the compact one (covered by the Night Planning tests).
final class IPadPlanningUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "regular width only")
    }

    @MainActor
    private func launch(step: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData", "-JamaalPlan", String(step)]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        return app
    }

    @MainActor
    private func rail(_ step: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "planRail-\(step)").firstMatch
    }

    /// "Done", "Current step" or "Later": what each step says about itself to VoiceOver.
    @MainActor
    private func state(_ step: String, in app: XCUIApplication) -> String? { rail(step, in: app).value as? String }

    @MainActor
    private func waitForState(_ expected: String, of step: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: rail(step, in: app))
        XCTAssertEqual(XCTWaiter().wait(for: [match], timeout: 8), .completed, "\(step) is \(String(describing: state(step, in: app)))", file: file, line: line)
    }

    @MainActor
    func testTheRailListsTheFiveStepsAndMarksTheOpenOne() throws {
        let app = launch(step: 3)
        XCTAssertTrue(rail("build", in: app).waitForExistence(timeout: 10))
        for step in ["review", "carry", "build", "load", "close"] {
            XCTAssertTrue(rail(step, in: app).exists, step)
        }
        XCTAssertEqual(state("review", in: app), "Done")
        XCTAssertEqual(state("carry", in: app), "Done")
        XCTAssertEqual(state("build", in: app), "Current step")
        XCTAssertEqual(state("load", in: app), "Later")
        XCTAssertEqual(state("close", in: app), "Later")
        XCTAssertTrue(app.buttons["planSkip"].exists, "Skip tonight is in the rail")
        XCTAssertTrue(app.buttons["planContinue"].exists)
    }

    @MainActor
    func testContinueMovesTheRailOnAndTheStepBehindSaysWhatItDid() throws {
        let app = launch(step: 3)
        XCTAssertTrue(rail("build", in: app).waitForExistence(timeout: 10))
        app.buttons["planContinue"].tap()
        waitForState("Current step", of: "load", in: app)
        XCTAssertEqual(state("build", in: app), "Done")
        XCTAssertTrue(rail("build", in: app).label.contains("task"), "a step behind carries its summary: \(rail("build", in: app).label)")
    }

    @MainActor
    func testTappingAStepBehindGoesBackToIt() throws {
        let app = launch(step: 3)
        XCTAssertTrue(rail("build", in: app).waitForExistence(timeout: 10))
        rail("review", in: app).tap()
        waitForState("Current step", of: "review", in: app)
        XCTAssertEqual(state("build", in: app), "Later")
    }

    @MainActor
    func testTappingAStepAheadDoesNothing() throws {
        let app = launch(step: 3)
        XCTAssertTrue(rail("build", in: app).waitForExistence(timeout: 10))
        rail("close", in: app).tap()
        XCTAssertEqual(state("build", in: app), "Current step", "ahead is reached with Continue")
    }

    @MainActor
    func testSkipTonightInTheRailLeavesPlanning() throws {
        let app = launch(step: 3)
        XCTAssertTrue(app.buttons["planSkip"].waitForExistence(timeout: 10))
        app.buttons["planSkip"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 8), "back on Today")
        XCTAssertFalse(rail("build", in: app).exists)
    }

    @MainActor
    func testCloseLeavesPlanningToo() throws {
        let app = launch(step: 3)
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["addButton"].waitForExistence(timeout: 8), "back on Today")
    }
}
