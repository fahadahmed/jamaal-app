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

    /// The model container. CloudKit is **off** until the paid Apple Developer Program provides the iCloud
    /// container (docs/roadmap/phases.md); sync is switched on by passing a configuration here.
    @MainActor
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try JamaalSchema.makeContainer(inMemory: inMemory)
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
        return result
    }
}
