//
//  StoreClient.swift
//  Jamaal
//

import Foundation
import StoreKit

/// The two plans. The trial is app-managed (no offer in the store), so a plan is just a price.
enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case yearly = "dev.fhdamd.jamaal.yearly"
    case monthly = "dev.fhdamd.jamaal.monthly"
    var id: String { rawValue }
    var title: String { self == .yearly ? "Yearly" : "Monthly" }
}

struct StoreOffer: Equatable, Identifiable {
    var plan: SubscriptionPlan
    var displayPrice: String
    /// "$2.08 a month" under the yearly plan.
    var perMonth: String?
    var id: String { plan.rawValue }
}

/// What the store says about this person right now.
struct StoreEntitlement: Equatable {
    var isActive: Bool
    var renewsOn: Date?
}

enum PurchaseOutcome: Equatable { case purchased, cancelled, pending, failed }

/// StoreKit behind a seam, so the rules are tested and the screens are driven in UI tests without the store.
@MainActor
protocol StoreClient {
    func offers() async -> [StoreOffer]
    /// What the store confirms now; `nil` when it can't be reached (the last answer then stands).
    func entitlement() async -> StoreEntitlement?
    func originalDownload() async -> Date?
    func purchase(_ plan: SubscriptionPlan) async -> PurchaseOutcome
    func restore() async -> Bool
    /// Emits whenever a transaction changes (a purchase on another device, a renewal, a refund).
    func changes() -> AsyncStream<Void>
}

@MainActor
struct SystemStoreClient: StoreClient {
    private let ids = SubscriptionPlan.allCases.map(\.rawValue)

    func offers() async -> [StoreOffer] {
        guard let products = try? await Product.products(for: ids) else { return [] }
        return SubscriptionPlan.allCases.compactMap { plan in
            guard let product = products.first(where: { $0.id == plan.rawValue }) else { return nil }
            let perMonth = plan == .yearly ? (product.price / 12).formatted(product.priceFormatStyle) + " a month" : nil
            return StoreOffer(plan: plan, displayPrice: product.displayPrice, perMonth: perMonth)
        }
    }

    func entitlement() async -> StoreEntitlement? {
        var active = false
        var renews: Date?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, ids.contains(transaction.productID), transaction.revocationDate == nil else { continue }
            active = true
            renews = [renews, transaction.expirationDate].compactMap { $0 }.max()
        }
        return StoreEntitlement(isActive: active, renewsOn: renews)
    }

    func originalDownload() async -> Date? {
        guard let result = try? await AppTransaction.shared, case .verified(let app) = result else { return nil }
        return app.originalPurchaseDate
    }

    func purchase(_ plan: SubscriptionPlan) async -> PurchaseOutcome {
        guard let product = try? await Product.products(for: [plan.rawValue]).first else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed }
                await transaction.finish()
                return .purchased
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .failed
            }
        } catch { return .failed }
    }

    func restore() async -> Bool { (try? await AppStore.sync()) != nil }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result { await transaction.finish() }
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

#if DEBUG
/// `-JamaalAccess …`, and every in-memory run: plans without the store, and a purchase that just turns the entitlement on.
@MainActor
final class FakeStoreClient: StoreClient {
    var active: Bool
    var originalDownloadDate: Date?
    private var continuation: AsyncStream<Void>.Continuation?

    init(active: Bool = false, originalDownload: Date? = nil) { self.active = active; originalDownloadDate = originalDownload }

    func offers() async -> [StoreOffer] {
        [StoreOffer(plan: .yearly, displayPrice: "$24.99", perMonth: "$2.08 a month"), StoreOffer(plan: .monthly, displayPrice: "$2.99", perMonth: nil)]
    }
    func entitlement() async -> StoreEntitlement? { StoreEntitlement(isActive: active, renewsOn: active ? Date.now.addingTimeInterval(30 * 86_400) : nil) }
    func originalDownload() async -> Date? { originalDownloadDate }
    func purchase(_ plan: SubscriptionPlan) async -> PurchaseOutcome { active = true; continuation?.yield(); return .purchased }
    func restore() async -> Bool { true }
    func changes() -> AsyncStream<Void> { AsyncStream { continuation = $0 } }
}
#endif
