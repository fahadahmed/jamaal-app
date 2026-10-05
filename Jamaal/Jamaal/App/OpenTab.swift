//
//  OpenTab.swift
//  Jamaal
//

import SwiftUI

private struct OpenTabKey: EnvironmentKey {
    static let defaultValue: (AppTab) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Switches the shell to another destination (a strip on Today opening Wellbeing, a card sending you to Habits).
    var openTab: (AppTab) -> Void {
        get { self[OpenTabKey.self] }
        set { self[OpenTabKey.self] = newValue }
    }
}
