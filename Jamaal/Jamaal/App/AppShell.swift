//
//  AppShell.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The shell: the system `TabView` in its adaptable style, so the same four destinations are a floating tab
/// bar on a phone and a sidebar on iPad and Mac. Anchors is hidden from the tab bar (it is a segment of
/// Habits there) and appears in the sidebar directly under Habits.
struct AppShell: View {
    @Environment(\.threads) private var threads
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: AppTab = .today

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.today.title, systemImage: AppTab.today.symbol, value: AppTab.today) { TodayScreen() }
            Tab(AppTab.habits.title, systemImage: AppTab.habits.symbol, value: AppTab.habits) { HabitsScreen() }
            // At compact width Anchors is a segment of Habits, so it isn't a tab at all (iOS keeps every tab it is
            // given in the phone's tab bar); at regular width it is a sidebar item that the top tab bar leaves out.
            if !AppNavigation.showsAnchorsSegment(sizeClass: sizeClass) {
                Tab(AppTab.anchors.title, systemImage: AppTab.anchors.symbol, value: AppTab.anchors) { AnchorsScreen() }
                    .defaultVisibility(.hidden, for: .tabBar)
            }
            Tab(AppTab.wellbeing.title, systemImage: AppTab.wellbeing.symbol, value: AppTab.wellbeing) { WellbeingScreen() }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: AppTab.settings) { SettingsScreen() }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Selection and links read in ink, as Design draws them; the one filled colour is `terra`, on buttons.
        .tint(threads.ink)
        .onChange(of: sizeClass) { _, _ in
            // Going compact removes the Anchors tab: land on Habits, where Anchors is a segment.
            if selection == .anchors, AppNavigation.showsAnchorsSegment(sizeClass: sizeClass) { selection = .habits }
        }
    }
}

#Preview {
    AppShell()
}
