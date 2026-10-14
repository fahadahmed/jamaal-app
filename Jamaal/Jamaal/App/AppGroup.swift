//
//  AppGroup.swift
//  Jamaal
//

import Foundation
import SwiftData
import JamaalCore

/// The App Group the app and its widgets share (docs/architecture/widgets-and-watch.md, "Where the store lives").
/// Its identifier is one build setting (`APP_GROUP_ID`, different on iOS and the Mac) that reaches Info.plist and the
/// entitlements. Without the entitlement (the free team, tests, previews) there is no container and everything stays
/// where it always was, so nothing here changes behaviour until the full entitlements are on.
enum AppGroup {
    /// The identifier from Info.plist, or nil when it is missing or still an unexpanded build variable.
    static func identifier(fromInfo value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty, !text.contains("$(") else { return nil }
        return text
    }

    static var identifier: String? { identifier(fromInfo: Bundle.main.object(forInfoDictionaryKey: "JamaalAppGroup")) }

    /// The group's folder, or nil when the app isn't entitled to the group.
    static var containerURL: URL? {
        identifier.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }

    /// Defaults shared with the widgets (the entitlement cache); the standard ones when there is no group.
    static func defaults(identifier: String?, containerAvailable: Bool) -> UserDefaults {
        guard containerAvailable, let identifier, let suite = UserDefaults(suiteName: identifier) else { return .standard }
        return suite
    }

    static var defaults: UserDefaults { defaults(identifier: identifier, containerAvailable: containerURL != nil) }
}

/// Where the SwiftData store lives. One place, so the app, the widgets and "reset this device's data" agree.
enum StoreLocation {
    static let fileName = "Jamaal.store"

    /// Inside the group container when there is one, else the default location.
    static func url(groupContainer: URL?, defaultURL: URL) -> URL {
        guard let groupContainer else { return defaultURL }
        return groupContainer
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    /// Makes sure the folder the store sits in exists (a group container starts empty).
    static func prepare(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    /// The store's URL now.
    static var current: URL {
        let standard = ModelConfiguration(schema: JamaalSchema.current, isStoredInMemoryOnly: false, cloudKitDatabase: .none).url
        return url(groupContainer: AppGroup.containerURL, defaultURL: standard)
    }
}
