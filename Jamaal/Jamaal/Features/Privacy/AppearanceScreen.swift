//
//  AppearanceScreen.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// Appearance (ST-07): the theme, where text size is set (the system's), and whether suggestion cards show. All per device.
struct AppearanceScreen: View {
    @Environment(\.threads) private var threads
    @Environment(ReminderCenter.self) private var reminders
    @AppStorage(AppPreferences.Keys.theme, store: AppPreferences.defaults) private var theme = AppTheme.system.rawValue
    @AppStorage(AppPreferences.Keys.suggestionCards, store: AppPreferences.defaults) private var suggestionCards = true

    var body: some View {
        #if os(macOS)
        macForm
        #else
        phoneBody
        #endif
    }

    private var phoneBody: some View {
        SettingsPage(title: "Appearance") {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("THEME").threadsType(.label).foregroundStyle(threads.ink2)
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases) { item in Text(item.title).tag(item.rawValue) }
                    }
                    .pickerStyle(.segmented).accessibilityIdentifier("themePicker")
                }
                VStack(spacing: 0) {
                    Divider().overlay(threads.line)
                    Button { reminders.openSystemSettings() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Text size").threadsType(.lede).foregroundStyle(threads.ink)
                                Text("Follows \(ReminderCenter.deviceName) Settings").threadsType(.meta).foregroundStyle(threads.ink2)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(threads.ink3)
                        }
                        .frame(minHeight: 64).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("textSize")
                    Divider().overlay(threads.line)
                    Toggle(isOn: $suggestionCards) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suggestion cards").threadsType(.lede).foregroundStyle(threads.ink)
                            Text("From Jamaal on Today and Wellbeing").threadsType(.meta).foregroundStyle(threads.ink2)
                        }
                    }
                    .tint(threads.accent).frame(minHeight: 64).accessibilityIdentifier("suggestionCards")
                    Divider().overlay(threads.line)
                }
            }
        }
    }
}

#if os(macOS)
// MARK: The Mac form (#368)

/// The same settings as the iPhone page, as a grouped Mac form: the theme as a segmented picker, and a system switch for the suggestion cards.
extension AppearanceScreen {
    fileprivate var macForm: some View {
        Form {
            Section {
                Picker(selection: $theme) {
                    ForEach(AppTheme.allCases) { item in Text(item.title).tag(item.rawValue) }
                } label: { MacRowLabel("Theme") }
                .pickerStyle(.segmented).accessibilityIdentifier("themePicker")
                LabeledContent {
                    Button("Open System Settings") { reminders.openSystemSettings() }.accessibilityIdentifier("textSize")
                } label: { MacRowLabel("Text size", note: "Follows \(ReminderCenter.deviceName) Settings") }
            }
            Section {
                Toggle(isOn: $suggestionCards) {
                    MacRowLabel("Suggestion cards", note: "From Jamaal on Today and Wellbeing")
                }
                .toggleStyle(.switch).accessibilityIdentifier("suggestionCards")
            }
        }
        .macSettingsForm()
    }
}
#endif
