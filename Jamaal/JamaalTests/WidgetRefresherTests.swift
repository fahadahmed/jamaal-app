//
//  WidgetRefresherTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// The widgets only know what the app tells them: a burst of saves is one reload, a reload "now" is immediate.
@MainActor
struct WidgetRefresherTests {

    private final class Counter { var reloads = 0 }

    @Test func aBurstOfRequestsIsOneReload() async throws {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .milliseconds(60)) { counter.reloads += 1 }
        for _ in 0..<5 { refresher.requestReload() }
        try await Task.sleep(for: .milliseconds(250))
        #expect(counter.reloads == 1)
    }

    @Test func requestsSpacedApartAreReloadedSeparately() async throws {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .milliseconds(40)) { counter.reloads += 1 }
        refresher.requestReload()
        try await Task.sleep(for: .milliseconds(200))
        refresher.requestReload()
        try await Task.sleep(for: .milliseconds(200))
        #expect(counter.reloads == 2)
    }

    @Test func reloadNowIsImmediateAndCancelsAPendingOne() async throws {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .milliseconds(80)) { counter.reloads += 1 }
        refresher.requestReload()
        refresher.reloadNow()
        #expect(counter.reloads == 1, "immediately")
        try await Task.sleep(for: .milliseconds(250))
        #expect(counter.reloads == 1, "the pending one was folded into it")
    }
}
