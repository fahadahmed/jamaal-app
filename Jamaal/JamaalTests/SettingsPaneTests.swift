//
//  SettingsPaneTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// The Mac Settings window's panes (#366): the same sections as the Settings list on the iPhone and iPad, in the same order, and the
/// last one used is the one it opens at.
@MainActor
struct SettingsPaneTests {

    @Test func thePanesAreTheSettingsListInItsOrder() {
        #expect(SettingsPane.allCases == [.capacity, .notifications, .categories, .appearance, .subscription, .sync, .yourData])
    }

    @Test func theWindowTitleIsTheListRowsNameAndTheToolbarKeepsItShort() {
        #expect(SettingsPane.allCases.map(\.title) == [
            "Capacity and day", "Notifications and times", "Categories", "Appearance", "Subscription", "iCloud sync", "Privacy and your data"])
        #expect(SettingsPane.allCases.map(\.toolbarTitle) == [
            "Day", "Notifications", "Categories", "Appearance", "Subscription", "iCloud", "Privacy"])
    }

    @Test func eachPaneHasItsOwnSymbolAndToolbarName() {
        #expect(Set(SettingsPane.allCases.map(\.symbol)).count == SettingsPane.allCases.count)
        #expect(Set(SettingsPane.allCases.map(\.toolbarTitle)).count == SettingsPane.allCases.count)
        #expect(SettingsPane.allCases.allSatisfy { !$0.symbol.isEmpty })
    }

    @Test func aSavedPaneComesBackAndAnythingElseOpensAtTheFirst() {
        #expect(SettingsPane.restoring("subscription") == .subscription)
        #expect(SettingsPane.restoring("yourData") == .yourData)
        #expect(SettingsPane.restoring(nil) == .capacity)
        #expect(SettingsPane.restoring("") == .capacity)
        #expect(SettingsPane.restoring("a pane that was removed") == .capacity)
    }

    private func defaults() -> UserDefaults {
        let name = "SettingsPaneTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func theRouterOpensAtTheLastPaneUsedAndRemembersEachChange() {
        let d = defaults()
        #expect(SettingsRouter(defaults: d).pane == .capacity, "first time: the first pane")
        let router = SettingsRouter(defaults: d)
        router.pane = .sync
        #expect(SettingsRouter(defaults: d).pane == .sync, "a later window opens where this one was left")
    }

    @Test func aRouteToASectionPicksThatPane() {
        let router = SettingsRouter(defaults: defaults())
        router.show(.subscription)
        #expect(router.pane == .subscription)
    }
}
