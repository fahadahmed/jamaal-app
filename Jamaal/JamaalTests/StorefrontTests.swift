//
//  StorefrontTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// A store that can't be reached: no answer, so the last one stands.
@MainActor
private struct OfflineStore: StoreClient {
    func offers() async -> [StoreOffer] { [] }
    func entitlement() async -> StoreEntitlement? { nil }
    func originalDownload() async -> Date? { nil }
    func purchase(_ plan: SubscriptionPlan) async -> PurchaseOutcome { .failed }
    func restore() async -> Bool { false }
    func changes() -> AsyncStream<Void> { AsyncStream { _ in } }
}

@MainActor
struct StorefrontTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func at(_ day: Int, _ hour: Int = 9) -> Date { boundary.instant(of: CalendarDate(year: 2026, month: 10, day: day)!, atMinute: hour * 60) }

    private func defaults() -> UserDefaults {
        let suite = "StorefrontTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private func settings(firstLaunch: Date) -> UserSettings { let s = UserSettings(); s.firstLaunchAt = firstLaunch; return s }

    // MARK: Access

    @Test func theTrialCountsLogicalDaysFromTheFirstLaunch() async {
        let store = Storefront(client: FakeStoreClient(), defaults: defaults())
        await store.refresh()
        let s = settings(firstLaunch: at(1))
        #expect(store.access(settings: s, boundary: boundary, now: at(1)) == .trial(daysLeft: 14))
        #expect(store.access(settings: s, boundary: boundary, now: at(6)) == .trial(daysLeft: 9))
        #expect(store.access(settings: s, boundary: boundary, now: at(14)) == .trial(daysLeft: 1))
        #expect(store.access(settings: s, boundary: boundary, now: at(15)) == .readOnly)
    }

    @Test func theStoresOriginalDownloadNeverRestartsTheTrial() async {
        let store = Storefront(client: FakeStoreClient(originalDownload: at(1)), defaults: defaults())
        await store.refresh()
        let reinstalled = settings(firstLaunch: at(10))                       // a fresh install on day 10
        #expect(store.trialStart(settings: reinstalled, boundary: boundary) == CalendarDate(year: 2026, month: 10, day: 1))
        #expect(store.access(settings: reinstalled, boundary: boundary, now: at(16)) == .readOnly)
    }

    @Test func aSubscriptionLiftsEverythingAtOnce() async {
        let fake = FakeStoreClient()
        let store = Storefront(client: fake, defaults: defaults())
        await store.refresh()
        let s = settings(firstLaunch: at(1))
        #expect(store.access(settings: s, boundary: boundary, now: at(20)) == .readOnly)
        await store.purchase(.monthly)
        #expect(store.entitlementActive && store.renewsOn != nil)
        #expect(store.access(settings: s, boundary: boundary, now: at(20)) == .subscribed)
    }

    @Test func aFailedLookupNeverLocksSomeoneWhoWasSubscribed() async {
        let d = defaults()
        let online = Storefront(client: FakeStoreClient(active: true), defaults: d)
        await online.refresh()
        #expect(online.entitlementActive)
        let offline = Storefront(client: OfflineStore(), defaults: d)           // same device, no connection
        #expect(offline.entitlementActive)                                       // the last answer stands from the first moment
        await offline.refresh()
        #expect(offline.entitlementActive)
        let neverSubscribed = Storefront(client: OfflineStore(), defaults: defaults())
        await neverSubscribed.refresh()
        #expect(!neverSubscribed.entitlementActive)
    }

    @Test func anExpiryTakesEffectOnceTheStoreConfirmsIt() async {
        let d = defaults()
        let fake = FakeStoreClient(active: true)
        let store = Storefront(client: fake, defaults: d)
        await store.refresh()
        fake.active = false
        await store.refresh()
        #expect(!store.entitlementActive && store.renewsOn == nil)
        #expect(!Storefront(client: OfflineStore(), defaults: d).entitlementActive)    // and that is what is remembered
    }

    @Test func restoringWithNothingToRestoreSaysSoCalmly() async {
        let store = Storefront(client: FakeStoreClient(), defaults: defaults())
        await store.restore()
        #expect(store.message == "No earlier purchase was found for this Apple ID.")
        let offline = Storefront(client: OfflineStore(), defaults: defaults())
        await offline.restore()
        #expect(offline.message == "Couldn't reach the App Store. Try again in a moment.")
        let subscribed = Storefront(client: FakeStoreClient(active: true), defaults: defaults())
        await subscribed.restore()
        #expect(subscribed.message == nil)
    }

    @Test func theFailedPurchaseSaysNothingWasCharged() async {
        let store = Storefront(client: OfflineStore(), defaults: defaults())
        await store.purchase(.yearly)
        #expect(store.message == "That didn't go through. Nothing was charged. Try again in a moment.")
        #expect(!store.entitlementActive)
    }

    // MARK: The paywall's and banner's memory

    @Test func thePaywallAndTheTrialBannerRememberTheirDayOnThisDevice() {
        let d = defaults()
        let store = Storefront(client: FakeStoreClient(), defaults: d)
        let day = CalendarDate(year: 2026, month: 10, day: 15)!
        #expect(store.paywallShownOn() == nil && store.trialBannerDismissedOn() == nil)
        store.markPaywallShown(on: day)
        store.dismissTrialBanner(on: day)
        let again = Storefront(client: FakeStoreClient(), defaults: d)
        #expect(again.paywallShownOn() == day && again.trialBannerDismissedOn() == day)
    }
}
