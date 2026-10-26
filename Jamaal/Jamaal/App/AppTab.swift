//
//  AppTab.swift
//  Jamaal
//

import JamaalCore
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

    /// At regular width the task detail sits beside the list as a panel; at compact width it is a bottom sheet. Regular width that is
    /// narrow (an iPhone Duo held fully open in portrait, 669 pt) is one column with the detail in a sheet, as drawn (`PaneLayout`).
    static func showsDetailPanel(sizeClass: UserInterfaceSizeClass?, availableWidth: CGFloat = 0) -> Bool {
        PaneLayout.usesTwoPanes(isRegularWidth: isRegular(sizeClass), availableWidth: availableWidth)
    }

    /// An iPhone, including an iPhone Duo's inner display, which is regular width but still has a bottom tab bar of four.
    static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    /// Regular width: an iPad (or a wide window on one), and always a Mac, whose windows are a desktop's and carry no size class.
    static func isRegular(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    /// The Habits | Anchors segment is for the phone layout, whatever its width: the floating tab bar has four tabs, never Anchors. At
    /// regular width on an iPad or a Mac, Anchors is its own item in the sidebar.
    static func showsAnchorsSegment(sizeClass: UserInterfaceSizeClass?) -> Bool {
        !isRegular(sizeClass) || isPhone
    }
}
