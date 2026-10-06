//
//  AccessGate.swift
//  Jamaal
//

import Observation
import SwiftUI
import JamaalCore

/// Whether the calm "Adding and planning need a subscription" sheet is up.
@MainActor
@Observable
final class AccessGate {
    var isShowingLocked = false
}

private struct RequireAccessKey: EnvironmentKey {
    static let defaultValue: (UserAction) -> Bool = { _ in true }
}

extension EnvironmentValues {
    /// Asks whether an action may go ahead. Living the day always may; shaping the plan may in a trial or when subscribed.
    /// When it may not, the one calm sheet explains and this returns `false`: nothing is hidden or greyed out, and nothing
    /// is half done.
    var requireAccess: (UserAction) -> Bool {
        get { self[RequireAccessKey.self] }
        set { self[RequireAccessKey.self] = newValue }
    }
}
