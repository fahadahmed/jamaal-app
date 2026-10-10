//
//  SmokeMacUITests.swift
//  JamaalMacUITests
//

import XCTest

/// The Mac app, driven on a real Mac: the first test only proves the target launches the app and finds its window.
final class SmokeMacUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testTheAppLaunchesWithAWindow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-JamaalInMemory", "-JamaalSampleData"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15))
    }
}
