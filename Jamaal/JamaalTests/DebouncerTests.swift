//
//  DebouncerTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// A burst of triggers is one action. These test the logic with `flush()`, which is what the timer calls once things are quiet, so
/// they do not depend on a clock (a shared CI runner is too unpredictable for one).
@MainActor
struct DebouncerTests {

    private final class Counter { var runs = 0 }

    @Test func aBurstIsOneRun() {
        let counter = Counter()
        let debouncer = Debouncer(delay: .seconds(60))
        for _ in 0..<5 { debouncer.schedule { counter.runs += 1 } }
        #expect(counter.runs == 0, "nothing runs before it has gone quiet")
        debouncer.flush()
        #expect(counter.runs == 1)
        debouncer.flush()
        #expect(counter.runs == 1, "and nothing is left to run")
    }

    @Test func theLatestActionIsTheOneThatRuns() {
        let ran = Counter()
        let debouncer = Debouncer(delay: .seconds(60))
        debouncer.schedule { ran.runs += 1 }
        debouncer.schedule { ran.runs += 10 }
        debouncer.flush()
        #expect(ran.runs == 10)
    }

    @Test func triggersAfterARunStartAFreshWait() {
        let counter = Counter()
        let debouncer = Debouncer(delay: .seconds(60))
        debouncer.schedule { counter.runs += 1 }
        debouncer.flush()
        debouncer.schedule { counter.runs += 1 }
        debouncer.flush()
        #expect(counter.runs == 2)
    }

    @Test func cancelDropsAPendingRun() {
        let counter = Counter()
        let debouncer = Debouncer(delay: .seconds(60))
        debouncer.schedule { counter.runs += 1 }
        debouncer.cancel()
        debouncer.flush()
        #expect(counter.runs == 0)
    }

    @Test func flushWithNothingScheduledDoesNothing() {
        let debouncer = Debouncer(delay: .seconds(60))
        debouncer.flush()                                                    // must not crash or run anything
    }
}
