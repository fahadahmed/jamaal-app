//
//  OnboardingUITests.swift
//  JamaalUITests
//

import XCTest

/// First launch: the nine screens, the first task, habit and Anchor, and the first Today.
final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalOnboarding", "-JamaalFakeNotifications", "notAsked", "-JamaalFakePlaces"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func tap(_ id: String, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "\(id) should be on screen")
        button.tap()
    }

    /// Meet, the idea, and (when this simulator has no iCloud account) the plain explanation.
    @MainActor
    private func passIntroduction(_ app: XCUIApplication) {
        tap("onboardingBegin", in: app)
        tap("onboardingContinue", in: app)
        if app.staticTexts["iCloud isn't on"].waitForExistence(timeout: 2) { tap("onboardingContinue", in: app) }
    }

    @MainActor
    private func passNormalDayAndReminders(_ app: XCUIApplication) {
        tap("onboardingContinue", in: app)                                       // the normal day
        tap("onboardingNotNow", in: app)                                         // reminders, later
    }

    @MainActor
    private func addFirstTask(_ app: XCUIApplication, title: String = "Call the clinic back") {
        let field = app.textFields["firstTaskTitle"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(title + "\n")
        tap("onboardingAddTask", in: app)
    }

    @MainActor
    func testTheWholeWayThroughLeavesATaskAHabitAndTheDayZeroCard() throws {
        let app = launch()
        passIntroduction(app)
        passNormalDayAndReminders(app)
        addFirstTask(app)
        tap("habitChoice-water", in: app)
        tap("onboardingAddHabit", in: app)
        tap("onboardingAnchorNotNow", in: app)
        let body = app.staticTexts["readyBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertEqual(body.label, "Until then, today has one task and one habit.")
        tap("onboardingOpenToday", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["tonightCard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Call the clinic back"].exists)
        XCTAssertTrue(app.staticTexts["Water"].exists || app.buttons["Water"].exists)
    }

    @MainActor
    func testTheNormalDayStepsAndThePickedValueShowsOnTheSettingsRow() throws {
        let app = launch()
        passIntroduction(app)
        let minutes = app.descendants(matching: .any)["dayMinutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 10))
        XCTAssertEqual(minutes.label, "3h")
        app.buttons["dayMore"].tap(); app.buttons["dayMore"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["dayMinutes"].label, "3h 30m")
        app.buttons["dayLess"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["dayMinutes"].label, "3h 15m")
        tap("onboardingContinue", in: app)
        tap("onboardingNotNow", in: app)
        addFirstTask(app)
        tap("habitChoice-water", in: app); tap("onboardingAddHabit", in: app)
        tap("onboardingAnchorNotNow", in: app)
        tap("onboardingOpenToday", in: app)
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.buttons["settings-capacity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-capacity"].label.contains("3h 15m"), app.buttons["settings-capacity"].label)
    }

    @MainActor
    func testABlankTaskOrHabitNameIsAskedForCalmly() throws {
        let app = launch()
        passIntroduction(app)
        passNormalDayAndReminders(app)
        tap("onboardingAddTask", in: app)
        XCTAssertTrue(app.staticTexts["Give it a name first."].waitForExistence(timeout: 5))
        addFirstTask(app)
        tap("habitChoice-other", in: app)
        tap("onboardingAddHabit", in: app)
        XCTAssertTrue(app.staticTexts["Give it a name first."].waitForExistence(timeout: 5))
        let name = app.textFields["firstHabitName"]
        name.tap(); name.typeText("Stretch\n")
        tap("onboardingAddHabit", in: app)
        XCTAssertTrue(app.buttons["onboardingAnchorNotNow"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAFirstAnchorIsMadeFromItsPresetAndCountsOnTheReadyScreen() throws {
        let app = launch()
        passIntroduction(app)
        passNormalDayAndReminders(app)
        addFirstTask(app)
        tap("habitChoice-quran", in: app); tap("onboardingAddHabit", in: app)
        tap("anchorChoice-binNight", in: app)
        tap("saveAnchorRule", in: app)
        let body = app.staticTexts["readyBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertEqual(body.label, "Until then, today has one task, one habit and one Anchor.")
    }

    @MainActor
    func testAllowingNotificationsGoesOnToTheFirstTask() throws {
        let app = launch()
        passIntroduction(app)
        tap("onboardingContinue", in: app)
        tap("onboardingAllow", in: app)
        XCTAssertTrue(app.textFields["firstTaskTitle"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testBackReturnsToThePreviousScreen() throws {
        let app = launch()
        passIntroduction(app)
        XCTAssertTrue(app.descendants(matching: .any)["dayMinutes"].waitForExistence(timeout: 10))
        tap("onboardingBack", in: app)
        XCTAssertTrue(app.staticTexts["Anchors you move around"].waitForExistence(timeout: 5) || app.staticTexts["iCloud isn't on"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWithoutTheFlagAnInMemoryLaunchSkipsOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboardingBegin"].exists)
    }
}
