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
    /// The running session, shown as a green chip at the bottom of the sidebar (it floated at the bottom of the window).
    let liveSession: WorkSession?
    let onOpenFocus: () -> Void
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if let liveSession { SidebarFocusChip(session: liveSession, action: onOpenFocus).padding(.horizontal, 12) }
                if canPlan { SidebarPlanTomorrow(action: onPlan) }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    }
}

/// The session in progress, at the bottom of the sidebar (macOS-TD-01): a green capsule with the task and its running time;
/// grey while paused. Clicking it opens the focus screen.
struct SidebarFocusChip: View {
    @Environment(\.threads) private var threads
    let session: WorkSession
    let action: () -> Void

    private var title: String { session.task?.title ?? session.habitWindow?.habit?.title ?? "" }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "clock").font(.body.weight(.medium))
                Text(title).threadsType(.row).lineLimit(1)
                Spacer(minLength: 4)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = FocusSessions.elapsedSeconds(of: session, at: context.date)
                    Text(FocusCopy.clock(seconds)).font(.custom("JetBrainsMono-Medium", size: 15, relativeTo: .body)).monospacedDigit()
                        .accessibilityLabel(session.pausedAt == nil ? "Timing" : "Paused")
                        .accessibilityValue(FocusCopy.clock(seconds))
                }
            }
            .foregroundStyle(threads.onAccent)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(session.pausedAt == nil ? threads.accent : threads.ink3))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the timer")
        .accessibilityIdentifier("focusChip")
    }
}
#endif
