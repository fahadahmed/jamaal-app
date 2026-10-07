//
//  PrivacyUITests.swift
//  JamaalUITests
//

import XCTest

/// Appearance, Your data, and the recovery screen.
final class PrivacyUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func open(_ row: String, in app: XCUIApplication) {
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let button = app.buttons[row]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    // MARK: Appearance

    @MainActor
    func testTheThemeIsChosenAndShowsOnTheSettingsRow() throws {
        let app = launch()
        open("settings-appearance", in: app)
        let picker = app.segmentedControls["themePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.buttons["System"].isSelected)
        picker.buttons["Dark"].tap()
        XCTAssertTrue(picker.buttons["Dark"].isSelected)
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["settings-appearance"].label.contains("Dark"), app.buttons["settings-appearance"].label)
    }

    @MainActor
    func testSuggestionCardsCanBeSwitchedOffAndTheReadingStays() throws {
        let app = launch(["-JamaalWellbeing", "strained"])
        open("settings-appearance", in: app)
        let toggle = app.switches["suggestionCards"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        app.buttons["Back"].tap()
        app.tabBars.buttons["Wellbeing"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["wellbeingScore"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["wellbeingCard"].exists)
    }

    // MARK: Your data

    @MainActor
    func testYourDataStatesWhatIsKeptAndExportSaysHowMuchWasExported() throws {
        let app = launch()
        open("settings-yourData", in: app)
        XCTAssertTrue(app.staticTexts["privacyStatement"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["privacyStatement"].label.contains("no account and no server"))
        XCTAssertTrue(app.staticTexts["exportMessage"].label.contains("Always available"))
        app.buttons["exportData"].tap()
        let message = app.staticTexts["exportMessage"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Exported '"), object: message)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 8), .completed, message.label)
    }

    @MainActor
    func testDeletingAsksTwiceCancelKeepsEverythingAndConfirmingStartsOver() throws {
        let app = launch()
        open("settings-yourData", in: app)
        app.buttons["deleteData"].tap()
        XCTAssertTrue(app.alerts["Delete all your data?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["onboardingBegin"].waitForExistence(timeout: 2))      // nothing happened

        app.buttons["deleteData"].tap()
        XCTAssertTrue(app.alerts["Delete all your data?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.alerts["Delete everything for good?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["onboardingBegin"].waitForExistence(timeout: 2))      // the second chance to stop

        app.buttons["deleteData"].tap()
        XCTAssertTrue(app.alerts["Delete all your data?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.alerts["Delete everything for good?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete everything"].tap()
        XCTAssertTrue(app.buttons["onboardingBegin"].waitForExistence(timeout: 10))      // back at the very beginning
    }

    // MARK: Recovery

    @MainActor
    func testAStoreThatWontOpenShowsTheRecoveryScreenAndTryAgainSaysSoCalmly() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalFailOpen"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["recoveryScreen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH \"Jamaal couldn't open its data on this\"")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["recoveryStillFailing"].exists)
        app.buttons["tryAgain"].tap()
        XCTAssertTrue(app.staticTexts["recoveryStillFailing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["resetData"].exists)                                  // nothing is lost by trying
    }

    @MainActor
    func testResettingAsksTwiceThenOpensTheApp() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalFailOpen"]
        app.launch()
        XCTAssertTrue(app.buttons["resetData"].waitForExistence(timeout: 10))
        app.buttons["resetData"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["resetData"].exists)                                  // cancelled: still on the recovery screen
        app.buttons["resetData"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.alerts["Reset now?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Reset"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    }
}
