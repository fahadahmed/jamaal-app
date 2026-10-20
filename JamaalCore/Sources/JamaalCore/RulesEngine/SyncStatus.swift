import Foundation

/// What this device knows about its own iCloud sync: when it last received and sent, and what went wrong last. The app feeds it
/// CloudKit's events; it holds no SwiftData objects, so it can be kept as JSON on the device. Nothing here leaves the device.
public struct SyncActivity: Codable, Equatable, Sendable {

    public enum Kind: String, Codable, Sendable {
        /// Setting up the iCloud zone.
        case setup
        /// Receiving changes from iCloud.
        case `import`
        /// Sending this device's changes.
        case export
    }

    public var lastImportAt: Date?
    public var lastExportAt: Date?
    public var lastError: String?
    public var lastErrorKind: Kind?
    public var lastErrorAt: Date?

    public init() {}

    /// Notes a finished event. One still in progress (`endedAt` nil) changes nothing; a failure is kept with what it was doing and
    /// when; a later success of the same kind clears it, a success of another kind does not.
    public mutating func record(_ kind: Kind, endedAt: Date?, succeeded: Bool, error: String?) {
        guard let endedAt else { return }
        if succeeded {
            switch kind {
            case .import: lastImportAt = endedAt
            case .export: lastExportAt = endedAt
            case .setup: break
            }
            if lastErrorKind == kind { lastError = nil; lastErrorKind = nil; lastErrorAt = nil }
        } else {
            lastError = error.flatMap { $0.isEmpty ? nil : $0 } ?? "It didn't say why."
            lastErrorKind = kind
            lastErrorAt = endedAt
        }
    }

    /// The most recent success of either kind.
    var lastSuccessAt: Date? { [lastImportAt, lastExportAt].compactMap { $0 }.max() }
}

/// Whether this device can reach an iCloud account, as the system reports it.
public enum SyncAccount: Equatable, Sendable {
    case available, noAccount, restricted
    /// Not asked yet, or the system couldn't say.
    case unknown
}

/// The words of the sync screen, in Jamaal's calm voice: plain facts, no alarm.
public enum SyncStatusCopy {

    public static func headline(isOn: Bool, account: SyncAccount, activity: SyncActivity, now: Date) -> String {
        guard isOn else { return "Off on this device. It keeps its own copy." }
        switch account {
        case .noAccount: return "Sign in to iCloud in Settings to sync."
        case .restricted: return "iCloud is restricted on this device."
        case .available, .unknown: break
        }
        if let errorAt = activity.lastErrorAt, activity.lastError != nil, errorAt >= (activity.lastSuccessAt ?? .distantPast) {
            return "The last attempt didn't go through."
        }
        return activity.lastSuccessAt == nil ? "Waiting for the first sync." : "Syncing normally."
    }

    /// "just now", "10 min ago", "2 h ago", "3 days ago"; "Not yet" when it hasn't happened.
    public static func when(_ date: Date?, now: Date) -> String {
        guard let date else { return "Not yet" }
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3_600: return "\(Int(seconds / 60)) min ago"
        case ..<86_400: return "\(Int(seconds / 3_600)) h ago"
        default:
            let days = Int(seconds / 86_400)
            return "\(days) \(days == 1 ? "day" : "days") ago"
        }
    }

    public static func accountText(_ account: SyncAccount) -> String {
        switch account {
        case .available: "signed in"
        case .noAccount: "not signed in"
        case .restricted: "restricted"
        case .unknown: "unknown"
        }
    }

    public static func kindText(_ kind: SyncActivity.Kind) -> String {
        switch kind {
        case .setup: "setting up"
        case .import: "receiving"
        case .export: "sending"
        }
    }

    /// One block of plain text to paste when asking for help. It holds no tasks, habits or titles.
    public static func details(
        isOn: Bool, account: SyncAccount, activity: SyncActivity, container: String, device: String, now: Date
    ) -> String {
        var lines = [
            "Device: \(device)",
            "Container: \(container)",
            "Sync: \(isOn ? "on" : "off")",
            "iCloud account: \(accountText(account))",
            "Last received: \(when(activity.lastImportAt, now: now))",
            "Last sent: \(when(activity.lastExportAt, now: now))",
        ]
        if let error = activity.lastError, let kind = activity.lastErrorKind {
            lines.append("Last problem: \(error) (\(kindText(kind)), \(when(activity.lastErrorAt, now: now)))")
        } else {
            lines.append("Last problem: none")
        }
        return lines.joined(separator: "\n")
    }
}
