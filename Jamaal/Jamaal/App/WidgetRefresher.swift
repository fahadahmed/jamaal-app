//
//  WidgetRefresher.swift
//  Jamaal
//

import Foundation
import WidgetKit

/// Tells the widgets the data changed. A widget plans its own updates (an Anchor opening or closing, the planning time, the day's
/// end), so it knows nothing about a task ticked, onboarding finished or a change arriving from iCloud unless the app says so.
/// A burst of saves is one reload.
@MainActor
final class WidgetRefresher {
    static let shared = WidgetRefresher()

    private let delay: Duration
    private let reload: () -> Void
    private var pending: Task<Void, Never>?

    init(delay: Duration = .seconds(1), reload: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.delay = delay
        self.reload = reload
    }

    /// Reloads after things have been quiet for `delay`.
    func requestReload() {
        pending?.cancel()
        pending = Task { [delay, reload] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            reload()
        }
    }

    /// Reloads now (the app is coming forward or leaving it), folding in anything pending.
    func reloadNow() {
        pending?.cancel()
        pending = nil
        reload()
    }
}
