//
//  PrayerPlaceTracker.swift
//  Jamaal
//

import Foundation
import SwiftData
import JamaalCore

/// Keeps a prayer rule's place current when the device travels (docs/schema/anchor.md, "Location"). It only reads the
/// location when permission was already given, never asks, and writes only when this device has moved about 25 km, so a
/// Mac at home never moves a place an iPhone set.
@MainActor
enum PrayerPlaceTracker {
    static func refresh(in context: ModelContext, finder: (any PlaceFinding)? = nil) async {
        let finder = finder ?? PlaceFinders.make()
        guard finder.canReadQuietly else { return }
        let rules = ((try? context.fetch(FetchDescriptor<AnchorRule>())) ?? []).filter { rule in
            guard !rule.isArchived, case .prayer(let config) = rule.config else { return false }
            return config.location?.mode == "device"
        }
        guard !rules.isEmpty, let place = await finder.current() else { return }
        let reading = place.location(mode: "device")
        var moved = false
        for rule in rules where PrayerEditing.followDevice(rule, reading: reading) { moved = true }
        if moved { AppEngine.syncAnchors(in: context) }
    }
}
