//
//  AppBootstrapTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// SwiftUI may build the `App` value more than once per launch; what start-up does must still happen once.
@MainActor
struct AppBootstrapTests {

    @Test func theBundledFontsRegisterAndAskingAgainDoesNotRegisterThemAgain() {
        #expect(AppBootstrap.fonts.isEmpty, "every bundled font registered")
        #expect(AppBootstrap.fonts.isEmpty)                      // a second ask reads the same stored result
    }

    @Test func thereIsOneNotificationDelegateHoweverOftenItIsAskedFor() {
        #expect(AppBootstrap.notificationDelegate === AppBootstrap.notificationDelegate)
    }

    @Test func theFirstContainerIsOpenedOnceAndShared() {
        let first = AppBootstrap.firstContainer
        let second = AppBootstrap.firstContainer
        #expect(first != nil)
        #expect(first === second, "the same container each time, not another opened on the same store")
    }
}
