//
//  WidgetRefresherTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// The widgets only know what the app tells them: a burst of saves is one reload, a reload "now" is immediate. Tested with
/// `flushPending()` (what the timer does once things are quiet) so no clock is involved.
@MainActor
struct WidgetRefresherTests {

    private final class Counter { var reloads = 0 }

    @Test func aBurstOfRequestsIsOneReload() {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .seconds(60)) { counter.reloads += 1 }
        for _ in 0..<5 { refresher.requestReload() }
        #expect(counter.reloads == 0)
        refresher.flushPending()
        #expect(counter.reloads == 1)
    }

    @Test func requestsAfterAReloadAreReloadedSeparately() {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .seconds(60)) { counter.reloads += 1 }
        refresher.requestReload()
        refresher.flushPending()
        refresher.requestReload()
        refresher.flushPending()
        #expect(counter.reloads == 2)
    }

    @Test func reloadNowIsImmediateAndCancelsAPendingOne() {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .seconds(60)) { counter.reloads += 1 }
        refresher.requestReload()
        refresher.reloadNow()
        #expect(counter.reloads == 1, "immediately")
        refresher.flushPending()
        #expect(counter.reloads == 1, "the pending one was folded into it")
    }
}
