//
//  DebouncerTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// A burst of triggers is one action, run once things have gone quiet.
@MainActor
struct DebouncerTests {

    private final class Counter { var runs = 0 }

    @Test func aBurstIsOneRunAfterTheQuiet() async throws {
        let counter = Counter()
        let debouncer = Debouncer(delay: .milliseconds(60))
        for _ in 0..<5 { debouncer.schedule { counter.runs += 1 } }
        #expect(counter.runs == 0, "not before it has gone quiet")
        try await Task.sleep(for: .milliseconds(250))
        #expect(counter.runs == 1)
    }

    @Test func triggersSpacedApartRunSeparately() async throws {
        let counter = Counter()
        let debouncer = Debouncer(delay: .milliseconds(40))
        debouncer.schedule { counter.runs += 1 }
        try await Task.sleep(for: .milliseconds(200))
        debouncer.schedule { counter.runs += 1 }
        try await Task.sleep(for: .milliseconds(200))
        #expect(counter.runs == 2)
    }

    @Test func theLatestActionIsTheOneThatRuns() async throws {
        let ran = Counter()
        let debouncer = Debouncer(delay: .milliseconds(40))
        debouncer.schedule { ran.runs += 1 }
        debouncer.schedule { ran.runs += 10 }
        try await Task.sleep(for: .milliseconds(200))
        #expect(ran.runs == 10)
    }

    @Test func cancelDropsAPendingRun() async throws {
        let counter = Counter()
        let debouncer = Debouncer(delay: .milliseconds(40))
        debouncer.schedule { counter.runs += 1 }
        debouncer.cancel()
        try await Task.sleep(for: .milliseconds(200))
        #expect(counter.runs == 0)
    }
}
