//
//  Storefront.swift
//  Jamaal
//

import Foundation
import Observation
import SwiftData
import JamaalCore

/// The app's view of the store and of access: the plans, whether a subscription is active (the last answer stands when the
/// store can't be reached), and the access state the rest of the app reads: trial, subscribed or read-only.
@MainActor
@Observable
final class Storefront {
    private(set) var offers: [StoreOffer] = []
    private(set) var entitlementActive: Bool
    private(set) var renewsOn: Date?
    private(set) var originalDownload: Date?
    private(set) var isWorking = false
    var message: String?

    private let client: any StoreClient
    private let defaults: UserDefaults
    private var started = false
    #if DEBUG
    /// `-JamaalAccess`: forces the state for looking at each screen. Injectable so unit tests never inherit a host argument.
    private let accessOverride: DebugLaunch.AccessOverride?
    #endif

    private enum Keys { static let lastKnown = "entitlementLastKnown", renews = "entitlementRenewsOn", paywallShownOn = "paywallShownOn", trialBannerDismissedOn = "trialBannerDismissedOn" }

    #if DEBUG
    init(client: (any StoreClient)? = nil, defaults: UserDefaults? = nil, accessOverride: DebugLaunch.AccessOverride? = DebugLaunch.access) {
        self.accessOverride = accessOverride
        self.client = client ?? Storefront.debugClient() ?? SystemStoreClient()
        let store = defaults ?? Storefront.standardDefaults
        self.defaults = store
        entitlementActive = EntitlementCache.isActive(confirmed: nil, lastKnown: store.object(forKey: Keys.lastKnown) as? Bool)
        renewsOn = store.object(forKey: Keys.renews) as? Date
    }
    #else
    init(client: (any StoreClient)? = nil, defaults: UserDefaults? = nil) {
        self.client = client ?? SystemStoreClient()
        let store = defaults ?? Storefront.standardDefaults
        self.defaults = store
        entitlementActive = EntitlementCache.isActive(confirmed: nil, lastKnown: store.object(forKey: Keys.lastKnown) as? Bool)
        renewsOn = store.object(forKey: Keys.renews) as? Date
    }
    #endif

    private static var standardDefaults: UserDefaults {
        #if DEBUG
        if DebugLaunch.inMemory, let suite = UserDefaults(suiteName: "JamaalInMemoryStorefront") {
            suite.removePersistentDomain(forName: "JamaalInMemoryStorefront")
            return suite
        }
        #endif
        return .standard
    }

    #if DEBUG
    private static func debugClient() -> (any StoreClient)? {
        guard DebugLaunch.inMemory || DebugLaunch.access != nil else { return nil }
        return FakeStoreClient(active: DebugLaunch.access == .subscribed)
    }
    #endif

    // MARK: Loading

    /// Loads the plans and the entitlement, then keeps both current as transactions arrive. Safe to call again.
    func start() async {
        await refresh()
        guard !started else { return }
        started = true
        for await _ in client.changes() { await refresh() }
    }

    func refresh() async {
        offers = await client.offers()
        originalDownload = await client.originalDownload()
        let confirmed = await client.entitlement()
        entitlementActive = EntitlementCache.isActive(confirmed: confirmed?.isActive, lastKnown: defaults.object(forKey: Keys.lastKnown) as? Bool)
        if let confirmed {
            defaults.set(confirmed.isActive, forKey: Keys.lastKnown)
            renewsOn = confirmed.isActive ? confirmed.renewsOn : nil
            defaults.set(renewsOn, forKey: Keys.renews)
        }
    }

    func purchase(_ plan: SubscriptionPlan) async {
        isWorking = true; message = nil
        let outcome = await client.purchase(plan)
        await refresh()
        switch outcome {
        case .purchased: message = nil
        case .cancelled: message = nil
        case .pending: message = "Your purchase is waiting for approval. Jamaal will unlock when it comes through."
        case .failed: message = "That didn't go through. Nothing was charged. Try again in a moment."
        }
        isWorking = false
    }

    func restore() async {
        isWorking = true; message = nil
        let ok = await client.restore()
        await refresh()
        message = !ok ? "Couldn't reach the App Store. Try again in a moment." : (entitlementActive ? nil : "No earlier purchase was found for this Apple ID.")
        isWorking = false
    }

    // MARK: Access

    /// The trial's start: the earlier of the store's original-download date and the synced first launch.
    func trialStart(settings: UserSettings?, boundary: DayBoundary) -> CalendarDate? {
        Trial.start(originalDownload: originalDownload.map(boundary.logicalDate(at:)), firstLaunch: settings?.firstLaunchAt.map(boundary.logicalDate(at:)))
    }

    /// Trial, subscribed or read-only, for `now`.
    func access(settings: UserSettings?, boundary: DayBoundary, now: Date = .now) -> AccessState {
        #if DEBUG
        if let override = accessOverride {
            switch override {
            case .subscribed: return .subscribed
            case .readOnly: return entitlementActive ? .subscribed : .readOnly          // a purchase still lifts it
            case .trial(let daysLeft): return entitlementActive ? .subscribed : .trial(daysLeft: daysLeft)
            }
        }
        #endif
        return Trial.state(today: boundary.logicalDate(at: now), start: trialStart(settings: settings, boundary: boundary), hasEntitlement: entitlementActive)
    }

    func access(in context: ModelContext, now: Date = .now) -> AccessState {
        access(settings: try? context.fetch(FetchDescriptor<UserSettings>()).min { $0.createdAt < $1.createdAt },
               boundary: TodayDay.boundary(in: context), now: now)
    }

    // MARK: The paywall's and banner's local memory (per device)

    func paywallShownOn() -> CalendarDate? { (defaults.string(forKey: Keys.paywallShownOn)).flatMap(CalendarDate.init(isoString:)) }
    func markPaywallShown(on day: CalendarDate) { defaults.set(day.isoString, forKey: Keys.paywallShownOn) }
    func trialBannerDismissedOn() -> CalendarDate? { (defaults.string(forKey: Keys.trialBannerDismissedOn)).flatMap(CalendarDate.init(isoString:)) }
    func dismissTrialBanner(on day: CalendarDate) { defaults.set(day.isoString, forKey: Keys.trialBannerDismissedOn) }
}
