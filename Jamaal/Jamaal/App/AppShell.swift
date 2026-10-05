//
//  AppShell.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import JamaalCore
import ThreadsTokens

/// The shell: the system `TabView` in its adaptable style, so the same four destinations are a floating tab
/// bar on a phone and a sidebar on iPad and Mac. Anchors is hidden from the tab bar (it is a segment of
/// Habits there) and appears in the sidebar directly under Habits.
struct AppShell: View {
    @Environment(\.threads) private var threads
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context
    @State private var selection: AppTab = .today
    @Environment(ReminderCenter.self) private var reminders
    @Query(sort: \UserSettings.createdAt) private var settingsRows: [UserSettings]
    @State private var coordinator = FocusCoordinator()
    // The one live session, and the Anchors the chip's single line is drawn from.
    @Query(filter: #Predicate<WorkSession> { $0.outcome == "running" && $0.endedAt == nil }) private var liveSessions: [WorkSession]
    @Query private var anchors: [AnchorInstance]

    /// First launch: until onboarding is completed (a second device on the account has it already). Debug in-memory runs
    /// skip it unless asked, so tests don't change.
    private var showsOnboarding: Bool {
        #if DEBUG
        if DebugLaunch.inMemory && !DebugLaunch.onboarding { return false }
        #endif
        return Onboarding.isNeeded(settingsRows.first)
    }

    private var debugStartStep: Int {
        #if DEBUG
        return DebugLaunch.onboardingStep ?? 0
        #else
        return 0
        #endif
    }

    private var liveSession: WorkSession? { liveSessions.min { $0.startedAt < $1.startedAt } }

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
        // The chip (or, for five seconds after Done, its Undo toast) sits above the tab bar on every tab.
        .focusAccessory(isEnabled: liveSession != nil || coordinator.toast != nil) {
            if let toast = coordinator.toast {
                UndoToast(title: toast.title) { coordinator.undoToast() }
            } else if let live = liveSession {
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    FocusChip(session: live, edge: FocusSessions.approachingEdge(anchors: anchors, now: timeline.date)) {
                        coordinator.isShowingFocus = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: .constant(showsOnboarding)) {
            OnboardingFlow(startAt: OnboardingStep(rawValue: debugStartStep) ?? .meet)
        }
        .environment(coordinator)
        .environment(\.openTab) { selection = $0 }
        .onAppear {
            coordinator.context = context
            #if DEBUG
            if let tab = DebugLaunch.tab { selection = tab }
            if DebugLaunch.openFocus { coordinator.isShowingFocus = true }
            #endif
        }
        // Any save (a habit logged, a night planned, a rule edited) may change what should be scheduled.
        .task {
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) { reminders.scheduleReplan(in: context) }
        }
        .onChange(of: reminders.route) { _, route in
            switch route {
            case .planning, .today: selection = .today
            case .subscription: selection = .settings
            case nil: break
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                coordinator.expireToastIfNeeded()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { coordinator.isShowingFocus && liveSession != nil }, set: { coordinator.isShowingFocus = $0 })) {
            if let live = liveSession { FocusScreen(session: live).environment(coordinator) }
        }
        .sheet(isPresented: Binding(get: { coordinator.settling != nil }, set: { if !$0 { coordinator.cancelSettle() } })) {
            if let settling = coordinator.settling { SettleSheet(settling: settling).environment(coordinator) }
        }
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

/// The chip's home above the tab bar. The system accessory can be switched off from iOS 26.1; on 26.0 it simply
/// has nothing in it when no session is running.
private extension View {
    @ViewBuilder
    func focusAccessory<Accessory: View>(isEnabled: Bool, @ViewBuilder content: @escaping () -> Accessory) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: isEnabled, content: content)
        } else {
            tabViewBottomAccessory(content: content)
        }
    }
}
