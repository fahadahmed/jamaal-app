//
//  SettingsScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Settings (ST-01). On Mac this becomes the `Settings` scene (⌘,) instead of a sidebar item. Only the rows that exist
/// are shown: Notifications and times, Appearance, Subscription, iCloud and Privacy arrive with their own changes.
struct SettingsScreen: View {
    @Environment(\.threads) private var threads
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]
    @Query private var categories: [TaskCategory]
    @Environment(ReminderCenter.self) private var reminders

    enum Destination: Hashable { case capacity, notifications, categories }

    var body: some View {
        let _ = categories.map { [$0.name, $0.isArchived ? "1" : "0"] }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                    Text("Settings").threadsType(.display(.large)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        Divider().overlay(threads.line)
                        row("Capacity and day", settings.first.map(SettingsCopy.capacitySummary) ?? "", .capacity)
                        row("Notifications and times",
                            ReminderCopy.homeValue(switchOn: reminders.remindersOnThisDevice, permission: reminders.permission, device: ReminderCenter.deviceName),
                            .notifications)
                        row("Categories", "\(categories.filter { !$0.isArchived }.count)", .categories)
                    }
                }
                .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.row).padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(threads.app)
            .toolbar(.hidden, for: .navigationBar)
            .task { await reminders.refresh() }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .capacity: CapacityAndDayScreen()
                case .notifications: NotificationsScreen()
                case .categories: CategoriesScreen()
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, _ destination: Destination) -> some View {
        NavigationLink(value: destination) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink)
                Spacer(minLength: ThreadsSpace.tight)
                Text(value).threadsType(.lede).foregroundStyle(threads.ink2)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
            }
            .frame(minHeight: 64).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings-\(destination)")
        .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
    }
}

/// A pushed settings screen's frame: a glass Back circle over a large title, as in the frames.
struct SettingsPage<Content: View>: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> AnyView
    @ViewBuilder var content: () -> Content

    init(title: String, subtitle: String? = nil, trailing: @escaping () -> AnyView = { AnyView(EmptyView()) }, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle; self.trailing = trailing; self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text(title).threadsType(.display(.large)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                    if let subtitle { Text(subtitle).threadsType(.lede).foregroundStyle(threads.ink2) }
                }
                content()
            }
            .padding(.horizontal, ThreadsSpace.gutter).padding(.top, 76).padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .top) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                        .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Back")
                Spacer()
                trailing()
            }
            .padding(.horizontal, ThreadsSpace.row).padding(.top, ThreadsSpace.hair)
        }
        .background(threads.app)
        .toolbar(.hidden, for: .navigationBar)
    }
}
