//
//  SettingsPane.swift
//  Jamaal
//

import Foundation
import Observation

/// The sections of Settings, in the order of the Settings list on the iPhone and iPad. On the Mac each is a pane of the Settings window
/// (#366): the toolbar shows `toolbarTitle` and the window's title is `title`.
enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case capacity, notifications, categories, appearance, subscription, sync, yourData

    var id: String { rawValue }

    /// The row's name in the Settings list, and the Mac window's title.
    var title: String {
        switch self {
        case .capacity: "Capacity and day"
        case .notifications: "Notifications and times"
        case .categories: "Categories"
        case .appearance: "Appearance"
        case .subscription: "Subscription"
        case .sync: "iCloud sync"
        case .yourData: "Privacy and your data"
        }
    }

    /// Short enough for a toolbar button.
    var toolbarTitle: String {
        switch self {
        case .capacity: "Day"
        case .notifications: "Notifications"
        case .categories: "Categories"
        case .appearance: "Appearance"
        case .subscription: "Subscription"
        case .sync: "iCloud"
        case .yourData: "Privacy"
        }
    }

    var symbol: String {
        switch self {
        case .capacity: "sun.max"
        case .notifications: "bell"
        case .categories: "tag"
        case .appearance: "circle.lefthalf.filled"
        case .subscription: "creditcard"
        case .sync: "icloud"
        case .yourData: "hand.raised"
        }
    }

    static let storageKey = "macSettingsPane"

    /// The pane saved last time; the first one when nothing, or something that no longer exists, was saved.
    static func restoring(_ raw: String?) -> SettingsPane { raw.flatMap(SettingsPane.init(rawValue:)) ?? .capacity }
}

/// Which pane the Settings window shows. Anything in the main window that opens Settings sets it first; it is remembered, so the window
/// opens where it was left (the HIG asks for this).
@MainActor
@Observable
final class SettingsRouter {
    var pane: SettingsPane { didSet { defaults.set(pane.rawValue, forKey: SettingsPane.storageKey) } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pane = SettingsPane.restoring(defaults.string(forKey: SettingsPane.storageKey))
    }

    func show(_ pane: SettingsPane) { self.pane = pane }
}
