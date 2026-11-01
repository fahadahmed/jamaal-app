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
        let status = SubscriptionCopy.status(access, trialStart: start, renewsOn: renews, isBeta: store.isBeta,
                                             purchaseTesting: store.canTestPurchases, hasSubscription: store.entitlementActive)
        page(access: access, status: status)
        .task { await store.refresh() }
        .sheetSized(isPresented: $showingPlans) { PaywallScreen() }
    }

    @ViewBuilder private func page(access: AccessState, status: (label: String, line: String)) -> some View {
        #if os(macOS)
        macForm(access: access, status: status)
        #else
        SettingsPage(title: "Subscription") {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text(status.label).threadsType(.label).foregroundStyle(threads.ink2).accessibilityIdentifier("subscriptionLabel")
                    Text(status.line).threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("subscriptionLine")
                }
                if store.isBeta {
                    Toggle(isOn: Binding(get: { store.purchaseTesting }, set: { store.purchaseTesting = $0 })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test purchases").threadsType(.lede).foregroundStyle(threads.ink)
                            Text("Beta only, on this device. Nothing is charged.").threadsType(.meta).foregroundStyle(threads.ink2)
                        }
                    }
                    .tint(threads.accent).frame(minHeight: 60).accessibilityIdentifier("betaPurchaseTesting")
                }
                if access != .subscribed || (store.canTestPurchases && !store.entitlementActive) {
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
                    row(SubscriptionCopy.termsOfUseTitle, trailing: "arrow.up.right", id: "termsOfUse") { openURL(SubscriptionLinks.termsOfUse) }
                    row(SubscriptionCopy.privacyPolicyTitle, trailing: "arrow.up.right", id: "privacyPolicy") { openURL(SubscriptionLinks.privacyPolicy) }
                }
                if let message = store.message {
                    Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("subscriptionMessage")
                }
            }
        }
        #endif
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

#if os(macOS)
// MARK: The Mac form (#369)

/// The same settings as the iPhone page, as a grouped Mac form: where things stand, the plans, and the App Store's own links.
extension SubscriptionScreen {
    fileprivate func macForm(access: AccessState, status: (label: String, line: String)) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text(status.label).threadsType(.label).foregroundStyle(threads.ink2).accessibilityIdentifier("subscriptionLabel")
                    Text(status.line).threadsType(.body).foregroundStyle(threads.ink).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("subscriptionLine")
                }
                if access != .subscribed || (store.canTestPurchases && !store.entitlementActive) {
                    Button("See plans") { showingPlans = true }.buttonStyle(.borderedProminent).accessibilityIdentifier("seePlans")
                }
            }
            if store.isBeta {
                Section {
                    Toggle(isOn: Binding(get: { store.purchaseTesting }, set: { store.purchaseTesting = $0 })) {
                        MacRowLabel("Test purchases", note: "Beta only, on this device. Nothing is charged.")
                    }
                    .toggleStyle(.switch).accessibilityIdentifier("betaPurchaseTesting")
                }
            }
            Section {
                macLink("Restore purchases", id: "restorePurchases") { Task { await store.restore() } }
                macLink("Manage in the App Store", external: true, id: "manageSubscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") { openURL(url) }
                }
                macLink(SubscriptionCopy.termsOfUseTitle, external: true, id: "termsOfUse") { openURL(SubscriptionLinks.termsOfUse) }
                macLink(SubscriptionCopy.privacyPolicyTitle, external: true, id: "privacyPolicy") { openURL(SubscriptionLinks.privacyPolicy) }
            }
            if let message = store.message {
                Section { MacFormNote(message, isError: true).accessibilityIdentifier("subscriptionMessage") }
            }
        }
        .macSettingsForm()
    }

    /// A row that is one button across the whole row: its title, and an arrow at the right when it leaves the app.
    private func macLink(_ title: String, external: Bool = false, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).threadsType(.body).foregroundStyle(threads.ink)
                Spacer()
                if external { Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(threads.ink3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }
}
#endif
