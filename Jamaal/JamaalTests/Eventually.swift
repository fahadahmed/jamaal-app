//
//  Eventually.swift
//  JamaalTests
//

import Foundation

/// Waits until `condition` holds, polling, for up to `timeout`. Returns whether it held. A test that waits for something to happen
/// uses this instead of a fixed sleep, which fails on a slow or stalled machine (a CI runner).
@MainActor
func eventually(timeout: Duration = .seconds(15), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

/// Lets work that should NOT happen have every chance to: cancelled work never runs, so a pause can only make such a test pass
/// late, never fail wrongly.
@MainActor
func settle(_ duration: Duration = .milliseconds(150)) async {
    try? await Task.sleep(for: duration)
}
