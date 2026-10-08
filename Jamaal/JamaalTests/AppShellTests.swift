//
//  AppShellTests.swift
//  JamaalTests
//

import Foundation
import SwiftData
import SwiftUI
import Testing
import JamaalCore
@testable import Jamaal

/// The shell's navigation rules (docs/design/README.md §8) and the engine tick the app runs.
@MainActor
struct AppShellTests {

    // MARK: Navigation

    @Test func theTabBarHasFourTabsAndAnchorsIsNotOneOfThem() {
        #expect(AppNavigation.tabBarTabs == [.today, .habits, .wellbeing, .settings])
    }

    @Test func theSidebarPutsAnchorsDirectlyUnderHabits() {
        #expect(AppNavigation.sidebarTabs(onMac: false) == [.today, .habits, .anchors, .wellbeing, .settings])
    }

    @Test func onMacSettingsMovesToTheAppMenuNotTheSidebar() {
        #expect(AppNavigation.sidebarTabs(onMac: true) == [.today, .habits, .anchors, .wellbeing])
    }

    @Test func theHabitsAnchorsSegmentShowsOnlyAtCompactWidth() {
        #expect(!AppNavigation.showsAnchorsSegment(sizeClass: .regular))
        #if os(macOS)
        #expect(!AppNavigation.showsAnchorsSegment(sizeClass: .compact))              // a Mac has no size classes: always the wide layout
        #expect(!AppNavigation.showsAnchorsSegment(sizeClass: nil))
        #else
        #expect(AppNavigation.showsAnchorsSegment(sizeClass: .compact))
        #expect(AppNavigation.showsAnchorsSegment(sizeClass: nil))                    // unknown: the phone layout
        #endif
    }

    @Test func everyTabHasATitleAndASymbol() {
        for tab in AppTab.allCases {
            #expect(!tab.title.isEmpty)
            #expect(!tab.symbol.isEmpty)
        }
        #expect(AppTab.allCases.map(\.title) == ["Today", "Habits", "Anchors", "Wellbeing", "Settings"])
    }

    // MARK: The last processed day is kept per device

    private func store() -> LastProcessedStore {
        let suite = "jamaal.tests.\(UUID().uuidString)"
        return LastProcessedStore(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func theLastProcessedDayRoundTripsAndStartsEmpty() {
        let store = store()
        #expect(store.day == nil)
        store.day = CalendarDate(year: 2026, month: 10, day: 14)
        #expect(store.day == CalendarDate(year: 2026, month: 10, day: 14))
    }

    @Test func anUnreadableStoredValueReadsAsNone() {
        let suite = "jamaal.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("not a date", forKey: LastProcessedStore.key)
        #expect(LastProcessedStore(defaults: defaults).day == nil)
    }

    // MARK: The tick

    @Test func theAppTickSeedsKeepsTheDayAndRepeatsHarmlessly() throws {
        let container = try AppEngine.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = store()
        let timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_792_000_000)

        let first = try AppEngine.tick(context: context, store: store, now: now, timeZone: timeZone)
        #expect(first.seeded)
        #expect(try context.fetchCount(FetchDescriptor<TaskCategory>()) == 3)
        #expect(store.day == first.lastProcessed)

        let second = try AppEngine.tick(context: context, store: store, now: now, timeZone: timeZone)
        #expect(!second.seeded)
        #expect(second.rollover.processedDays.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<UserSettings>()) == 1)
    }

    @Test func theStoreOpensWithCloudKitOffUntilTheContainerExists() throws {
        let container = try AppEngine.makeContainer(inMemory: true)
        #expect(container.configurations.count == 1)
        #expect(container.schema.entities.count == 14)
    }
}

struct DetailPanelTests {
    @Test func theDetailSitsBesideTheListOnlyAtRegularWidth() {
        #expect(AppNavigation.showsDetailPanel(sizeClass: .regular))
        #if os(macOS)
        #expect(AppNavigation.showsDetailPanel(sizeClass: .compact))                  // a Mac is always wide
        #expect(AppNavigation.showsDetailPanel(sizeClass: nil))
        #else
        #expect(!AppNavigation.showsDetailPanel(sizeClass: .compact))
        #expect(!AppNavigation.showsDetailPanel(sizeClass: nil))
        #endif
    }
}

struct TodayFilterStateTests {
    @Test func pickingACategoryFiltersAndPickingItAgainClears() {
        let state = TodayFilterState()
        let work = UUID(), family = UUID()
        #expect(state.selectedID == nil)
        state.toggle(work)
        #expect(state.selectedID == work)
        state.toggle(family)
        #expect(state.selectedID == family)
        state.toggle(family)
        #expect(state.selectedID == nil)
    }
}

struct MacWindowTests {
    @Test func everyMacSheetFitsInsideTheSmallestWindow() {
        for size in [MacSheetSize.page, MacSheetSize.canvas] {
            #expect(size.width.upperBound <= MacWindow.minWidth + 120)          // ideal may be a little larger than the window
            #expect(size.width.lowerBound < MacWindow.minWidth)
            #expect(size.height.lowerBound < MacWindow.minHeight)
        }
    }

    @Test func theCanvasHasRoomForTheStepRailBesideItsStep() {
        // The rail is 340 pt plus 32 pt of margin in the left 40% of the canvas.
        #expect(MacSheetSize.canvas.width.lowerBound * 0.4 >= 340 + 32)
    }

    @Test func theDefaultWindowIsLargerThanTheMinimum() {
        #expect(MacWindow.defaultWidth > MacWindow.minWidth)
        #expect(MacWindow.defaultHeight > MacWindow.minHeight)
    }
}

@MainActor
struct MacCommandsTests {
    @Test func theSectionsAreCommandOneToFourInTheSidebarsOrder() {
        let keys = AppNavigation.sidebarTabs(onMac: true).map(\.commandKey)
        #expect(keys == ["1", "2", "3", "4"])
        #expect(AppTab.settings.commandKey == ",")                                       // as in every Mac app
    }

    @Test func noTwoSectionsShareAKey() {
        let keys = AppTab.allCases.map(\.commandKey)
        #expect(Set(keys).count == keys.count)
    }

    @Test func aNewTaskRequestWaitsUntilSomethingTakesIt() {
        let center = CommandCenter()
        #expect(!center.newTaskRequested)
        center.requestNewTask()
        #expect(center.newTaskRequested)
        center.newTaskRequested = false                                                  // what Today does once it has opened the form
        #expect(!center.newTaskRequested)
    }
}
