//
//  SyncMode.swift
//  Jamaal
//

import SwiftData

/// Whether the store syncs through iCloud. It does only when the app is signed with its App Group (which comes with the iCloud
/// entitlement); tests, previews, unsigned builds, CI and a store held in memory stay local.
enum SyncMode: Equatable {
    case off
    case cloudKit(container: String)

    /// The iCloud container in the entitlements (`Jamaal.entitlements`).
    static let containerID = "iCloud.dev.fhdamd.Jamaal"

    static func resolve(inMemory: Bool, hasGroup: Bool, disabled: Bool) -> SyncMode {
        guard !inMemory, hasGroup, !disabled else { return .off }
        return .cloudKit(container: containerID)
    }

    var database: ModelConfiguration.CloudKitDatabase {
        switch self {
        case .off: .none
        case .cloudKit(let container): .private(container)
        }
    }
}
