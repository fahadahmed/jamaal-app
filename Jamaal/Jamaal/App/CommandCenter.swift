//
//  CommandCenter.swift
//  Jamaal
//

import SwiftUI
import Observation

/// What the Mac's menu commands ask the focused window to do. A request waits here until the screen that owns it is on
/// screen, so a command works from whichever section is showing.
@MainActor
@Observable
final class CommandCenter {
    /// New Task: Today opens its Add form when it sees this.
    var newTaskRequested = false
    /// Counts Return presses on a selected task (Mac); a change asks the open detail to focus its title.
    var editTitleRequests = 0
    /// How many of those the open detail has acted on, so a request is handled once, whether the detail was already open or opened with it.
    @ObservationIgnored var handledEditTitleRequests = 0

    func requestNewTask() { newTaskRequested = true }
}

/// The actions a window offers the menu bar.
struct JamaalCommandActions {
    var newTask: () -> Void
    var planTomorrow: () -> Void
    var go: (AppTab) -> Void
}

private struct JamaalActionsKey: FocusedValueKey {
    typealias Value = JamaalCommandActions
}

extension FocusedValues {
    /// Set by the focused window's shell; nil when no window is focused, which greys the commands out.
    var jamaalActions: JamaalCommandActions? {
        get { self[JamaalActionsKey.self] }
        set { self[JamaalActionsKey.self] = newValue }
    }
}

extension AppTab {
    /// The ⌘ number or key that goes to this section (Settings is ⌘, as on every Mac).
    var commandKey: Character {
        switch self {
        case .today: "1"
        case .habits: "2"
        case .anchors: "3"
        case .wellbeing: "4"
        case .settings: ","
        }
    }
}

#if os(macOS)
/// The Mac menu bar: New Task, Plan Tomorrow and the sections. Settings… (⌘,) comes from the `Settings` scene.
struct JamaalCommands: Commands {
    @FocusedValue(\.jamaalActions) private var actions

    var body: some Commands {
        // One window, so ⌘N is a new task rather than a new window.
        CommandGroup(replacing: .newItem) {
            Button("New Task") { actions?.newTask() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions == nil)
        }
        CommandMenu("Plan") {
            Button("Plan Tomorrow") { actions?.planTomorrow() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }
        CommandGroup(after: .sidebar) {
            Divider()
            ForEach(AppNavigation.sidebarTabs(onMac: true)) { tab in
                Button(tab.title) { actions?.go(tab) }
                    .keyboardShortcut(KeyEquivalent(tab.commandKey), modifiers: .command)
                    .disabled(actions == nil)
            }
        }
    }
}
#endif
