//
//  WidgetStore.swift
//  JamaalWidgets
//

import Foundation
import SwiftData
import JamaalCore

/// Opens the shared store read-only and reads Today from it. It never creates a store: before the App Group is on (or before
/// the app has run) there is nothing to read, and the widget shows its quiet empty state.
@MainActor
enum WidgetStore {
    enum Failure: Error { case noStore }

    private static var container: ModelContainer?

    static func snapshot(at date: Date) throws -> WidgetSnapshot {
        let context = ModelContext(try openContainer())
        // The entitlement cache isn't shared yet, so a widget reads as in the trial: "View only" comes with that slice.
        return try WidgetSnapshot.make(in: context, now: date, access: .trial(daysLeft: 1))
    }

    private static func openContainer() throws -> ModelContainer {
        if let container { return container }
        let url = StoreLocation.current
        guard FileManager.default.fileExists(atPath: url.path) else { throw Failure.noStore }
        let configuration = ModelConfiguration(schema: JamaalSchema.current, url: url, allowsSave: false, cloudKitDatabase: .none)
        let opened = try JamaalSchema.makeContainer(configuration: configuration)
        container = opened
        return opened
    }
}
