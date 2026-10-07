//
//  AppPreferences.swift
//  Jamaal
//

import Foundation
import SwiftUI

/// A person's look and feel, kept on this device (not synced): the theme, and whether Jamaal's suggestion cards show.
enum AppPreferences {
    /// The device's own preferences; in the in-memory test mode a fresh set each launch, so tests don't leak into each other.
    static let defaults: UserDefaults = {
        #if DEBUG
        if DebugLaunch.inMemory, let suite = UserDefaults(suiteName: "JamaalInMemoryPreferences") {
            suite.removePersistentDomain(forName: "JamaalInMemoryPreferences")
            return suite
        }
        #endif
        return .standard
    }()

    enum Keys {
        static let theme = "appearanceTheme"
        static let suggestionCards = "suggestionCardsOn"
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// `nil` follows the system.
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
