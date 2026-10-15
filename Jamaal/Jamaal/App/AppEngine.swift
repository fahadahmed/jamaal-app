//
//  AppEngine.swift
//  Jamaal
//

import Foundation
import SwiftData
import JamaalCore

/// The most recent ended day the rollover has processed, kept **per device** (not synced): another device's
/// progress says nothing about this one, and every rollover step is idempotent anyway.
struct LastProcessedStore {
    static let key = "engine.lastProcessedDay"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var day: CalendarDate? {
        get { defaults.string(forKey: Self.key).flatMap(CalendarDate.init(isoString:)) }
        nonmutating set {
            if let newValue { defaults.set(newValue.isoString, forKey: Self.key) } else { defaults.removeObject(forKey: Self.key) }
        }
    }
}

/// The app's side of the engine: the store, and the tick that keeps it current.
enum AppEngine {

    /// The model container. It syncs through iCloud (the private database of `iCloud.dev.fhdamd.Jamaal`) when the app is signed
    /// with its App Group; see `SyncMode`.
    @MainActor
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        #if DEBUG
        if DebugLaunch.failOpen && !storeWasReset { throw CocoaError(.fileReadCorruptFile) }
        let inMemory = inMemory || DebugLaunch.inMemory
        #endif
        return try JamaalSchema.makeContainer(inMemory: inMemory, configuration: try groupConfiguration(inMemory: inMemory))
    }

    /// The store inside the App Group container, when the app has one (so widgets read the same data), syncing through
    /// iCloud; nil otherwise, which leaves the store where it has always been, local.
    @MainActor
    private static func groupConfiguration(inMemory: Bool) throws -> ModelConfiguration? {
        guard !inMemory, AppGroup.containerURL != nil else { return nil }
        let url = StoreLocation.current
        try StoreLocation.prepare(url)
        #if DEBUG
        let disabled = DebugLaunch.noCloudKit
        #else
        let disabled = false
        #endif
        let sync = SyncMode.resolve(inMemory: inMemory, hasGroup: true, disabled: disabled)
        return ModelConfiguration(schema: JamaalSchema.current, url: url, cloudKitDatabase: sync.database)
    }

    #if DEBUG
    /// `-JamaalFailOpen` keeps failing to open until the store has been reset, to look at the recovery screen.
    nonisolated(unsafe) static var storeWasReset = false
    #endif

    /// Removes this device's local store (and its journal files) so the next open starts empty. It never touches the iCloud copy.
    @MainActor
    static func deleteLocalStore() {
        #if DEBUG
        storeWasReset = true
        if DebugLaunch.inMemory { return }
        #endif
        let url = StoreLocation.current
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// Runs the engine tick (seed, dedup, rollover catch-up, Anchors) and remembers the processed day.
    /// Called on launch and whenever the app becomes active.
    @MainActor
    @discardableResult
    static func tick(
        context: ModelContext, store: LastProcessedStore = LastProcessedStore(), now: Date = .now, timeZone: TimeZone = .current
    ) throws -> EngineTickResult {
        let result = try EngineTick.run(in: context, now: now, timeZone: timeZone, lastProcessed: store.day)
        store.day = result.lastProcessed
        #if DEBUG
        DebugLaunch.completeOnboardingForTests(in: context, now: now)
        DebugLaunch.insertSampleData(into: context, now: now)
        DebugLaunch.insertSampleAnchorRules(into: context, now: now)
        DebugLaunch.insertNormalDayHistory(into: context, now: now)
        DebugLaunch.insertWellbeingHistory(into: context, now: now)
        #endif
        return result
    }

    /// Brings Today's Anchors in line with the rules after one was made, edited, paused, archived or restored: a
    /// pending Anchor a rule no longer makes goes, and new ones appear. Attended, missed, skipped and delegated stay.
    @MainActor
    static func syncAnchors(in context: ModelContext, now: Date = .now, timeZone: TimeZone = .current) {
        let boundary = TodayDay.boundary(in: context, timeZone: timeZone)
        _ = try? AnchorGenerator.sync(in: context, boundary: boundary, now: now)
    }
}
