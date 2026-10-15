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

    private let debouncer: Debouncer
    private let reload: () -> Void

    init(delay: Duration = .seconds(1), reload: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.debouncer = Debouncer(delay: delay)
        self.reload = reload
    }

    /// Reloads after things have been quiet for the delay.
    func requestReload() {
        debouncer.schedule { [reload] in reload() }
    }

    /// Reloads now (the app is coming forward or leaving it), folding in anything pending.
    func reloadNow() {
        debouncer.cancel()
        reload()
    }

    /// Runs a pending reload now (what the timer does once things are quiet); for tests.
    func flushPending() { debouncer.flush() }
}
