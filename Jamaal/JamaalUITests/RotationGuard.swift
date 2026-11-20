//
//  RotationGuard.swift
//  JamaalUITests
//

import XCTest

extension XCTestCase {
    /// A test that needs the app held sideways asks for it and then calls this. On some simulators (an iPhone 17e on iOS 26.5; an iPad
    /// Pro 13" at times) the device turns but the app's window does not, so there is nothing sideways to test: say so and skip, instead of
    /// failing on a sidebar that only shows in landscape (#395, #407).
    @MainActor
    func skipUnlessSideways(_ app: XCUIApplication) throws {
        let window = app.windows.firstMatch
        let turned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in window.frame.width > window.frame.height }, object: nil)
        try XCTSkipUnless(XCTWaiter().wait(for: [turned], timeout: 6) == .completed, "this simulator did not rotate the app's window")
    }
}
