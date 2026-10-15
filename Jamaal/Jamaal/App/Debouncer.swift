//
//  Debouncer.swift
//  Jamaal
//

import Foundation

/// Runs an action once things have gone quiet: each new trigger replaces the pending one and restarts the wait.
@MainActor
final class Debouncer {
    private let delay: Duration
    private var pending: Task<Void, Never>?
    private var latest: (@MainActor () -> Void)?

    init(delay: Duration) { self.delay = delay }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        latest = action
        pending?.cancel()
        pending = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Runs the latest scheduled action now, once, and forgets it. The timer calls this when things have gone quiet; a test calls it
    /// instead of waiting.
    func flush() {
        pending?.cancel()
        pending = nil
        guard let action = latest else { return }
        latest = nil
        action()
    }

    func cancel() {
        pending?.cancel()
        pending = nil
        latest = nil
    }
}
