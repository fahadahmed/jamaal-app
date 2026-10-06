//
//  PaywallScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The calm paywall (SB-01): the two plans, Restore, and a plain Not now. No countdown, no pressure. Shown once on the
/// first open of each day once the trial has ended, and from Subscription at any time.
struct PaywallScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Storefront.self) private var store
    @State private var selected: SubscriptionPlan = .yearly

    var body: some View {
        let access = store.access(in: context)
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                Text(SubscriptionCopy.paywallEyebrow(access)).threadsType(.label).foregroundStyle(threads.ink2)
                Text(SubscriptionCopy.paywallTitle).threadsType(.display(.compact)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                Text(SubscriptionCopy.paywallBody).threadsType(.lede).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.tight)
            }
            if store.offers.isEmpty {
                Text(SubscriptionCopy.noPlans).threadsType(.body).foregroundStyle(threads.ink2).accessibilityIdentifier("noPlans")
            } else {
                VStack(spacing: ThreadsSpace.row) { ForEach(store.offers) { offer in planCard(offer) } }
            }
            if let message = store.message {
                Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("paywallMessage")
            }
            Spacer()
            Button { Task { await store.purchase(selected); if store.entitlementActive { dismiss() } } } label: {
                Text(SubscriptionCopy.subscribeButton(selected)).threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
            }
            .buttonStyle(.plain).disabled(store.offers.isEmpty || store.isWorking).opacity(store.offers.isEmpty ? 0.5 : 1).accessibilityIdentifier("subscribe")
            HStack {
                Button("Restore") { Task { await store.restore(); if store.entitlementActive { dismiss() } } }
                    .accessibilityIdentifier("restore")
                Spacer()
                Button("Not now") { dismiss() }.accessibilityIdentifier("notNow")
            }
            .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
        }
        .padding(.horizontal, ThreadsSpace.gutter).padding(.top, 72).padding(.bottom, ThreadsSpace.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(threads.app.ignoresSafeArea())
        .task { await store.refresh() }
        .interactiveDismissDisabled(store.isWorking)
    }

    private func planCard(_ offer: StoreOffer) -> some View {
        Button { selected = offer.plan } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.plan.title).threadsType(.row).foregroundStyle(threads.ink)
                    if let perMonth = offer.perMonth { Text(perMonth).threadsType(.body).foregroundStyle(threads.ink2) }
                }
                Spacer()
                Text(offer.displayPrice).threadsType(.row).foregroundStyle(threads.ink)
            }
            .padding(ThreadsSpace.row).frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(selected == offer.plan ? threads.card : .clear))
            .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(selected == offer.plan ? threads.ink : threads.line2, lineWidth: selected == offer.plan ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan-\(offer.plan.title.lowercased())")
        .accessibilityAddTraits(selected == offer.plan ? .isSelected : [])
    }
}
