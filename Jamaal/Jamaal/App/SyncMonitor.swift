//
//  SyncMonitor.swift
//  Jamaal
//

import CloudKit
import CoreData
import Foundation
import Observation
import JamaalCore

/// Watches the iCloud sync's own events (SwiftData mirrors through `NSPersistentCloudKitContainer`, which announces each setup,
/// import and export) and keeps the last of each on this device, so Settings can say what is happening. Nothing is sent anywhere:
/// it records times and the error text, never any of your data.
@MainActor @Observable
final class SyncMonitor {
    static let shared = SyncMonitor()

    private(set) var activity: SyncActivity
    private(set) var account: SyncAccount = .unknown

    /// Whether this build mirrors through iCloud (the same rule the store uses to open).
    let isOn: Bool

    private static let key = "syncActivity"
    private let defaults = UserDefaults.standard

    private init() {
        #if DEBUG
        let inMemory = DebugLaunch.inMemory
        let disabled = DebugLaunch.noCloudKit
        #else
        let inMemory = false
        let disabled = false
        #endif
        isOn = SyncMode.resolve(inMemory: inMemory, hasGroup: AppGroup.containerURL != nil, disabled: disabled) != .off
        activity = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(SyncActivity.self, from: $0) } ?? SyncActivity()
    }

    /// Starts listening. Called once, before the store opens, so the setup event is not missed.
    func start() {
        guard isOn else { return }
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            let kind: SyncActivity.Kind = switch event.type {
            case .setup: .setup
            case .import: .import
            case .export: .export
            @unknown default: .setup
            }
            let end = event.endDate, ok = event.succeeded
            if end != nil {                                          // an event still in progress isn't worth a line
                let name: DiagnosticName = switch kind { case .setup: .syncSetup; case .import: .syncImport; case .export: .syncExport }
                var fields: [DiagnosticEvent.Field] = [.init(.ok, .flag(ok))]
                if let error = event.error { fields.append(.init(.errorCode, .error(error))) }
                Diag.shared.record(name, level: ok ? .info : .error, fields)
            }
            let text = event.error.map { error -> String in
                let ns = error as NSError
                return "\(error.localizedDescription) (\(ns.domain) \(ns.code))"
            }
            MainActor.assumeIsolated { self?.record(kind, endedAt: end, succeeded: ok, error: text) }
        }
        Task { await refreshAccount() }
    }

    private func record(_ kind: SyncActivity.Kind, endedAt: Date?, succeeded: Bool, error: String?) {
        var next = activity
        next.record(kind, endedAt: endedAt, succeeded: succeeded, error: error)
        guard next != activity else { return }
        activity = next
        if let data = try? JSONEncoder().encode(next) { defaults.set(data, forKey: Self.key) }
    }

    /// Asks the system whether this device has an iCloud account the app can use.
    func refreshAccount() async {
        guard isOn else { return }
        do {
            switch try await CKContainer(identifier: SyncMode.containerID).accountStatus() {
            case .available: account = .available
            case .noAccount: account = .noAccount
            case .restricted: account = .restricted
            default: account = .unknown
            }
        } catch {
            account = .unknown
        }
    }
}
