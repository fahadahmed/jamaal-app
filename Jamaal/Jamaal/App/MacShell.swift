//
//  MacShell.swift
//  Jamaal
//

#if os(macOS)
import SwiftUI
import SwiftData
import JamaalCore
import ThreadsTokens

/// The Mac's navigation: a real sidebar beside the section (macOS-TD-01). SwiftUI's tab view has no sidebar style on a Mac,
/// so this is a split view with the same furniture as the iPad's sidebar: the wordmark, the sections with Today's count, the
/// Categories that filter Today, and Plan tomorrow at the bottom. Settings isn't here: on a Mac it is in the app menu (⌘,).
struct MacSidebar: View {
    @Environment(\.threads) private var threads
    @Binding var selection: AppTab
    let todayCount: Int
    let categories: [TaskCategory]
    let selectedCategoryID: UUID?
    let canPlan: Bool
    let onPickCategory: (UUID) -> Void
    let onPlan: () -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(AppNavigation.sidebarTabs(onMac: true)) { tab in
                Label(tab.title, systemImage: tab.symbol)
                    .tag(tab)
                    .badge(tab == .today ? todayCount : 0)
                    .accessibilityIdentifier("sidebar-\(tab.rawValue)")
            }
            if !categories.isEmpty {
                Section {
                    SidebarCategories(categories: categories, selectedID: selectedCategoryID, onPick: onPickCategory)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { SidebarWordmark().frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6) }
        .safeAreaInset(edge: .bottom, spacing: 0) { if canPlan { SidebarPlanTomorrow(action: onPlan) } }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    }
}
#endif
