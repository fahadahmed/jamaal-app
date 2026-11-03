//
//  StoreShotsUITests.swift
//  JamaalUITests
//

import XCTest

/// Takes the raw App Store pictures on an iPad in landscape (#362): the store dataset, Light appearance, a picture of the whole screen
/// attached to the results under the name `build.py` expects. It only runs when asked (`JAMAAL_STORE_SHOTS=1`, which
/// `assets/appstore/capture-ipad.sh` sets), so a normal run of the UI tests skips it.
final class StoreShotsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["JAMAAL_STORE_SHOTS"] == "1", "only when making the store pictures")
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the iPad pictures")
    }

    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    private func shot(_ name: String, _ extra: [String] = []) {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalStoreShots", "-JamaalDayStartMinute", "0", "-JamaalWeekdayLevel", "medium"] + extra
        app.launch()
        sleep(8)
        let picture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picture.name = name
        picture.lifetime = .keepAlways
        add(picture)
        app.terminate()
    }

    @MainActor
    func testTheIPadInLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        shot("1-today", ["-JamaalWellbeing", "steady"])
        shot("1b-today-open", ["-JamaalWellbeing", "steady", "-JamaalOpenTask"])
        shot("2-night-build", ["-JamaalEvening", "-JamaalPlan", "3"])
        shot("2-night-load", ["-JamaalEvening", "-JamaalPlan", "4"])
        shot("3-habits-open", ["-JamaalTab", "habits", "-JamaalOpenHabit"])
        shot("4-anchors-open", ["-JamaalTab", "anchors", "-JamaalOpenRule", "-JamaalAnchorRules"])
        shot("5-wellbeing", ["-JamaalTab", "wellbeing", "-JamaalWellbeing", "steady"])
        shot("6-focus", ["-JamaalBegin", "-JamaalOpenFocus"])
    }
}
