//
//  SubscriptionScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Subscription (ST-05): where things stand in the trial or after it, the plans, Restore, and the App Store's own management.
struct SubscriptionScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(Storefront.self) private var store
    @Query(sort: \UserSettings.createdAt) private var rows: [UserSettings]
    @State private var showingPlans = false

    var body: some View {
        let boundary = TodayDay.boundary(in: context)
        let access = store.access(settings: rows.first, boundary: boundary)
        let start = store.trialStart(settings: rows.first, boundary: boundary)
        let renews = store.renewsOn.map { $0.formatted(.dateTime.day().month(.wide).locale(.current)) }
        let status = SubscriptionCopy.status(access, trialStart: start, renewsOn: renews)
        SettingsPage(title: "Subscription") {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text(status.label).threadsType(.label).foregroundStyle(threads.ink2).accessibilityIdentifier("subscriptionLabel")
                    Text(status.line).threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("subscriptionLine")
                }
                if access != .subscribed {
                    Button { showingPlans = true } label: {
                        Text("See plans").threadsType(.row).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("seePlans")
                }
                VStack(spacing: 0) {
                    Divider().overlay(threads.line)
                    row("Restore purchases", id: "restorePurchases") { Task { await store.restore() } }
                    row("Manage in the App Store", trailing: "arrow.up.right", id: "manageSubscription") {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                    }
                }
                if let message = store.message {
                    Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("subscriptionMessage")
                }
            }
        }
        .task { await store.refresh() }
        .sheet(isPresented: $showingPlans) { PaywallScreen() }
    }

    private func row(_ title: String, trailing: String? = nil, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink)
                Spacer()
                if let trailing { Image(systemName: trailing).font(.footnote).foregroundStyle(threads.ink3) }
            }
            .frame(minHeight: 60).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
        .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
    }
}
