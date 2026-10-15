//
//  DebouncerTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// A burst of triggers is one action, run once things have gone quiet. The waits poll (`eventually`) instead of sleeping a fixed time,
/// so a slow machine only makes the test slower, never wrong.
@MainActor
struct DebouncerTests {

    private final class Counter { var runs = 0 }

    @Test func aBurstIsOneRunAfterTheQuiet() async {
        let counter = Counter()
        let debouncer = Debouncer(delay: .milliseconds(20))
        for _ in 0..<5 { debouncer.schedule { counter.runs += 1 } }
        #expect(counter.runs == 0, "not before it has gone quiet")
        #expect(await eventually { counter.runs >= 1 })
        await settle()                                                       // the four it replaced were cancelled, so none follows
        #expect(counter.runs == 1)
    }

    @Test func triggersSpacedApartRunSeparately() async {
        let counter = Counter()
        let debouncer = Debouncer(delay: .milliseconds(10))
        debouncer.schedule { counter.runs += 1 }
        #expect(await eventually { counter.runs == 1 })
        debouncer.schedule { counter.runs += 1 }
        #expect(await eventually { counter.runs == 2 })
    }

    @Test func theLatestActionIsTheOneThatRuns() async {
        let ran = Counter()
        let debouncer = Debouncer(delay: .milliseconds(20))
        debouncer.schedule { ran.runs += 1 }
        debouncer.schedule { ran.runs += 10 }
        #expect(await eventually { ran.runs > 0 })
        await settle()
        #expect(ran.runs == 10)
    }

    @Test func cancelDropsAPendingRun() async {
        let counter = Counter()
        let debouncer = Debouncer(delay: .milliseconds(20))
        debouncer.schedule { counter.runs += 1 }
        debouncer.cancel()
        await settle()
        #expect(counter.runs == 0)
    }
}
