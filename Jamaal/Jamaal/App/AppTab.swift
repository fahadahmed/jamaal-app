//
//  AppTab.swift
//  Jamaal
//

import SwiftUI

/// The app's destinations. Today, Habits, Wellbeing and Settings are the tab bar; Anchors is a segment of
/// Habits on a phone and its own sidebar item on iPad and Mac (docs/design/README.md §8).
enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case today, habits, anchors, wellbeing, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .habits: "Habits"
        case .anchors: "Anchors"
        case .wellbeing: "Wellbeing"
        case .settings: "Settings"
        }
    }

    /// The icon Design draws for it: a template vector asset (24 pt grid, 1.75 stroke, round caps), not an SF Symbol. An SF Symbol is
    /// heavier, and the system swaps the selected tab's for its solid variant (Habits turned into four filled squares).
    var icon: String {
        switch self {
        case .today: "TabToday"
        case .habits: "TabHabits"
        case .anchors: "TabAnchors"
        case .wellbeing: "TabWellbeing"
        case .settings: "TabSettings"
        }
    }
}

/// Which destinations appear where.
enum AppNavigation {
    /// The floating tab bar: four tabs, never Anchors.
    static let tabBarTabs: [AppTab] = [.today, .habits, .wellbeing, .settings]

    /// The sidebar on iPad and Mac, Anchors directly under Habits. On Mac, Settings lives in the app menu
    /// (the `Settings` scene, ⌘,) instead.
    static func sidebarTabs(onMac: Bool) -> [AppTab] {
        onMac ? [.today, .habits, .anchors, .wellbeing] : [.today, .habits, .anchors, .wellbeing, .settings]
    }

    /// At regular width the task detail sits beside the list as a panel; at compact width it is a bottom sheet.
    static func showsDetailPanel(sizeClass: UserInterfaceSizeClass?) -> Bool { isRegular(sizeClass) }

    /// Regular width: an iPad (or a wide window on one), and always a Mac, whose windows are a desktop's and carry no size class.
    static func isRegular(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    /// The Habits | Anchors segment is for the phone layout; at regular width Anchors is its own item.
    static func showsAnchorsSegment(sizeClass: UserInterfaceSizeClass?) -> Bool {
        !isRegular(sizeClass)
    }
}
