//
//  MacSettingsWindow.swift
//  Jamaal
//

#if os(macOS)
import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The Mac's Settings window (#366), opened from the app menu (⌘,): a toolbar of panes, one per section of the Settings list, as the
/// Human Interface Guidelines describe (`docs/design/mac-settings-window.md`). The panes show the same screens as the iPhone and iPad
/// until each gets its Mac form (#367 to #369).
struct MacSettingsWindow: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(Storefront.self) private var store
    @Environment(SettingsRouter.self) private var router
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @State private var gate = AccessGate()
    @State private var showingPaywall = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.pane) {
            ForEach(SettingsPane.allCases) { pane in
                NavigationStack { content(for: pane) }
                    .environment(\.isInPane, true)
                    .navigationTitle(pane.title)
                    .tabItem { Label(pane.toolbarTitle, systemImage: pane.symbol) }
                    .tag(pane)
            }
        }
        .frame(width: 620, height: 560)
        .background(threads.app)
        .accessibilityIdentifier("macSettingsWindow")
        // The same trial and read-only rules as the main window: Settings is not a way round them.
        .environment(\.requireAccess) { action in
            let boundary = TodayDay.boundary(in: context)
            if action.isAllowed(in: store.access(settings: settingsRows.first, boundary: boundary)) { return true }
            gate.isShowingLocked = true
            return false
        }
        .sheet(isPresented: $gate.isShowingLocked) {
            LockedSheet {
                gate.isShowingLocked = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showingPaywall = true }
            }
        }
        .sheetSized(isPresented: $showingPaywall) { PaywallScreen() }
    }

    @ViewBuilder private func content(for pane: SettingsPane) -> some View {
        switch pane {
        case .capacity: CapacityAndDayScreen()
        case .notifications: NotificationsScreen()
        case .categories: CategoriesScreen()
        case .appearance: AppearanceScreen()
        case .subscription: SubscriptionScreen()
        case .sync: SyncStatusScreen()
        case .yourData: YourDataScreen()
        }
    }
}
#endif
