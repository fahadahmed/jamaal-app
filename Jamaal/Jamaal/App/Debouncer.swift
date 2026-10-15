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

    init(delay: Duration) { self.delay = delay }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}
