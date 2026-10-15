//
//  WidgetRefresherTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// The widgets only know what the app tells them: a burst of saves is one reload, a reload "now" is immediate. The waits poll
/// (`eventually`) so a slow CI runner cannot fail them.
@MainActor
struct WidgetRefresherTests {

    private final class Counter { var reloads = 0 }

    @Test func aBurstOfRequestsIsOneReload() async {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .milliseconds(20)) { counter.reloads += 1 }
        for _ in 0..<5 { refresher.requestReload() }
        #expect(await eventually { counter.reloads >= 1 })
        await settle()
        #expect(counter.reloads == 1)
    }

    @Test func requestsSpacedApartAreReloadedSeparately() async {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .milliseconds(10)) { counter.reloads += 1 }
        refresher.requestReload()
        #expect(await eventually { counter.reloads == 1 })
        refresher.requestReload()
        #expect(await eventually { counter.reloads == 2 })
    }

    @Test func reloadNowIsImmediateAndCancelsAPendingOne() async {
        let counter = Counter()
        let refresher = WidgetRefresher(delay: .milliseconds(200)) { counter.reloads += 1 }
        refresher.requestReload()
        refresher.reloadNow()
        #expect(counter.reloads == 1, "immediately")
        await settle(.milliseconds(400))
        #expect(counter.reloads == 1, "the pending one was folded into it")
    }
}
