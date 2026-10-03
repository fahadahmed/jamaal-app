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

    /// The SF Symbol Design draws for it.
    var symbol: String {
        switch self {
        case .today: "text.alignleft"
        case .habits: "square.grid.2x2"
        case .anchors: "clock"
        case .wellbeing: "waveform.path.ecg"
        case .settings: "slider.vertical.3"
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

    /// The Habits | Anchors segment is for the phone layout; at regular width Anchors is its own item.
    static func showsAnchorsSegment(sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass != .regular
    }
}
