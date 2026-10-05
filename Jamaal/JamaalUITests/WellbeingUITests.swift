//
//  WellbeingUITests.swift
//  JamaalUITests
//

import XCTest

/// The Wellbeing tab in each state, and its strip and card on Today.
final class WellbeingUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ mode: String?, tab: String? = "Wellbeing") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"] + (mode.map { ["-JamaalWellbeing", $0] } ?? [])
        app.launch()
        if let tab {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
        }
        return app
    }

    @MainActor
    func testAFreshInstallIsGatheringDataWithNothingToFillIn() throws {
        let app = launch(nil)
        XCTAssertTrue(app.descendants(matching: .any)["wellbeingGathering"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["A reading appears after seven active days."].exists)
        XCTAssertTrue(app.staticTexts["Nothing to fill in. It comes only from what you already do."].exists)
        XCTAssertFalse(app.descendants(matching: .any)["wellbeingScore"].exists)
    }

    @MainActor
    func testFourActiveDaysShowFourOfSeven() throws {
        let app = launch("gathering")
        let count = app.descendants(matching: .any)["gatheringCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.label, "4 of 7 days")
    }

    @MainActor
    func testASteadyReadingShowsTheScoreTheTrendAndThePlainRead() throws {
        let app = launch("steady")
        let score = app.descendants(matching: .any)["wellbeingScore"]
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        XCTAssertNotNil(Int(score.label))
        XCTAssertEqual(app.staticTexts["wellbeingTrend"].label, "About the same as two weeks ago")
        let read = app.staticTexts["wellbeingRead"]
        XCTAssertTrue(read.label.hasPrefix("Most tasks got done, the Anchors held, and only two days ran heavy"), read.label)
        XCTAssertFalse(app.descendants(matching: .any)["wellbeingCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["wellbeingRow-tasks"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["wellbeingRow-heavy"].label.contains("2 of 14"))
    }

    @MainActor
    func testAStrainedReadingOffersOneChangeAndTakingItLowersTomorrow() throws {
        let app = launch("strained")
        let card = app.descendants(matching: .any)["wellbeingCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["wellbeingRead"].label, "The last three days were each over their budget.")
        XCTAssertTrue(app.staticTexts["The last three days were heavy. Make tomorrow a low day?"].exists)
        app.buttons["wellbeingAction"].tap()
        let outcome = app.staticTexts["wellbeingOutcome"]
        XCTAssertTrue(outcome.waitForExistence(timeout: 5))
        XCTAssertEqual(outcome.label, "Tomorrow is a low day.")
        XCTAssertFalse(card.exists)
    }

    @MainActor
    func testNotNowPutsTheCardAway() throws {
        let app = launch("strained")
        let card = app.descendants(matching: .any)["wellbeingCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.buttons["wellbeingNotNow"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: card)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["wellbeingScore"].exists)                 // the reading stays
    }

    @MainActor
    func testTodayShowsAStripThatOpensWellbeing() throws {
        let app = launch("steady", tab: nil)
        let strip = app.buttons["wellbeingStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        strip.tap()
        XCTAssertTrue(app.descendants(matching: .any)["wellbeingScore"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTodayStripSaysHowFarGatheringHasGot() throws {
        let app = launch("gathering", tab: nil)
        let strip = app.buttons["wellbeingStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        XCTAssertTrue(strip.label.contains("gathering data · 4 of 7"), strip.label)
    }

    @MainActor
    func testTheCardShowsOnTodayOnceAndItsActionWorksThere() throws {
        let app = launch("strained", tab: nil)
        let card = app.descendants(matching: .any)["wellbeingCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.buttons["wellbeingAction"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: card)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }
}
