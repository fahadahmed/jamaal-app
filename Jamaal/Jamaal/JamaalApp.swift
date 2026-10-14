//
//  JamaalApp.swift
//  Jamaal
//
//  Created by Fahad Ahmed on 25/9/2026.
//

import JamaalCore
import SwiftData
import SwiftUI
import UserNotifications
import ThreadsTokens

@main
struct JamaalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var container: ModelContainer?
    @State private var openFailedAgain = false
    @AppStorage(AppPreferences.Keys.theme, store: AppPreferences.defaults) private var theme = AppTheme.system.rawValue
    @State private var reminders = ReminderCenter()
    @State private var storefront = Storefront()
    private var notificationDelegate: NotificationDelegate { AppBootstrap.notificationDelegate }

    init() {
        // Fraunces, Hanken Grotesk and JetBrains Mono ship inside ThreadsKit; register them before the first view.
        let failures = AppBootstrap.fonts
        assert(failures.isEmpty, "Fonts failed to register: \(failures)")

        _ = AppBootstrap.notificationDelegate                       // the system's delegate, set once
        #if canImport(UIKit)
        TabBarAppearance.apply(JamaalPalette())
        #endif

        _container = State(initialValue: AppBootstrap.firstContainer)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .modelContainer(container)
                        .environment(reminders)
                        .environment(storefront)
                        .task { await storefront.start() }
                        .onAppear {
                            reminders.storefront = storefront
                            notificationDelegate.onRoute = { [reminders] route in reminders.route = route }
                            tick(container)
                            #if DEBUG
                            if let url = DebugLaunch.openURL { open(url, in: container) }
                            #endif
                        }
                        .onChange(of: scenePhase) { _, phase in
                            if phase == .active { tick(container) }
                        }
                        // A widget link takes the same path in as a notification tap.
                        .onOpenURL { url in open(url, in: container) }
                } else {
                    // A store that won't open must not crash the app: say so, and offer Try again or a reset.
                    RecoveryScreen(stillFailing: openFailedAgain, onTryAgain: tryAgain, onReset: reset)
                }
            }
            .environment(\.threads, JamaalPalette())
            .preferredColorScheme(AppTheme(rawValue: theme)?.scheme)
            #if os(macOS)
            .frame(minWidth: MacWindow.minWidth, minHeight: MacWindow.minHeight)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: MacWindow.defaultWidth, height: MacWindow.defaultHeight)
        .commands { JamaalCommands() }
        #endif
    }

    @MainActor
    private func tryAgain() {
        if let opened = try? AppEngine.makeContainer() { container = opened; openFailedAgain = false } else { openFailedAgain = true }
    }

    /// Removes this device's copy (after two confirmations on the recovery screen), then opens again.
    @MainActor
    private func reset() {
        AppEngine.deleteLocalStore()
        tryAgain()
    }

    /// Keeps the data current on launch and whenever the app becomes active.
    @MainActor
    /// A widget link takes the same path in as a notification tap: it sets the route the shell and Today already act on.
    /// A link that isn't one of ours is ignored.
    private func open(_ url: URL, in container: ModelContainer) {
        let today = TodayDay.boundary(in: container.mainContext).logicalDate(at: .now)
        if let route = JamaalLink.route(from: url, today: today) { reminders.route = route }
    }

    private func tick(_ container: ModelContainer) {
        do {
            try AppEngine.tick(context: container.mainContext)
            Task { await PrayerPlaceTracker.refresh(in: container.mainContext) }
            reminders.scheduleReplan(in: container.mainContext)
        } catch {
            assertionFailure("Engine tick failed: \(error)")
        }
    }
}
