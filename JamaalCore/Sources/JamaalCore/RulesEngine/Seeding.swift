import Foundation
import SwiftData

/// First-launch seeding: one `UserSettings` row and the three default categories.
///
/// Two devices can each seed before they have synced, so every step only creates what is
/// missing and [`Dedup`](x-source-tag://Dedup) merges any duplicates later. See
/// docs/journeys/walkthroughs/01-first-launch.md.
public enum Seeding {

    /// The seeded categories: preset key, name, colour. Their order is their `sortOrder`.
    static let defaultCategories: [(preset: CategoryPreset, name: String, color: CategoryColor)] = [
        (.personal, "Personal", .accent),
        (.family, "Family", .ochre),
        (.work, "Work", .blue),
    ]

    /// Creates whatever of the seed data is missing.
    ///
    /// - Settings: one row if none exists, with `firstLaunchAt` set to `now`. An existing row is
    ///   never touched, so `firstLaunchAt` is set once. **Only a build that starts the trial** (`startsTrial`)
    ///   sets it: a TestFlight beta shares the production iCloud container with the App Store release, so a
    ///   date set during the beta would have used up a tester's 14 days before the release. A row left
    ///   without one gets it on the first launch of a build that does start the trial.
    /// - Categories: each default is created only if no category with that `presetKey` exists,
    ///   archived or renamed ones included, so a user's changes are never undone.
    ///
    /// - Returns: `true` if anything was created.
    @MainActor
    @discardableResult
    public static func ensureSeeded(in context: ModelContext, now: Date, startsTrial: Bool = true) throws -> Bool {
        var created = false
        var claimed = false

        if try context.fetchCount(FetchDescriptor<UserSettings>()) == 0 {
            let settings = UserSettings()
            settings.firstLaunchAt = startsTrial ? now : nil
            settings.createdAt = now
            context.insert(settings)
            created = true
        } else if startsTrial {
            for settings in try context.fetch(FetchDescriptor<UserSettings>()) where settings.firstLaunchAt == nil {
                settings.firstLaunchAt = now
                claimed = true
            }
        }

        let existing = Set(try context.fetch(FetchDescriptor<TaskCategory>()).compactMap(\.presetKey))
        for (index, seed) in defaultCategories.enumerated() where !existing.contains(seed.preset.rawValue) {
            let category = TaskCategory(name: seed.name)
            category.presetKey = seed.preset.rawValue
            category.colorKey = seed.color.rawValue
            category.sortOrder = index
            category.createdAt = now
            context.insert(category)
            created = true
        }

        if created || claimed { try context.save() }
        return created
    }
}
