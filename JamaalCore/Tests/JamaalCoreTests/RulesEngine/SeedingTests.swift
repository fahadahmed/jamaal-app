import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// First-launch seeding (docs/journeys/walkthroughs/01-first-launch.md): one `UserSettings` row
/// and the three default categories keyed by `presetKey`, set up once and never duplicated.
@MainActor
struct SeedingTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeContext() throws -> ModelContext {
        ModelContext(try JamaalSchema.makeContainer(inMemory: true))
    }

    @Test func seedsSettingsAndTheThreeDefaultCategories() throws {
        let context = try makeContext()
        let created = try Seeding.ensureSeeded(in: context, now: now)
        #expect(created)

        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(settings.count == 1)
        #expect(settings.first?.firstLaunchAt == now)

        let categories = try context.fetch(FetchDescriptor<TaskCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(categories.map(\.presetKey) == ["personal", "family", "work"])
        #expect(categories.map(\.name) == ["Personal", "Family", "Work"])
        #expect(categories.map(\.color) == [.accent, .ochre, .blue])
        #expect(categories.map(\.sortOrder) == [0, 1, 2])
        #expect(categories.allSatisfy { !$0.isArchived })
    }

    @Test func seedingTwiceChangesNothing() throws {
        let context = try makeContext()
        _ = try Seeding.ensureSeeded(in: context, now: now)
        let created = try Seeding.ensureSeeded(in: context, now: now.addingTimeInterval(60))
        #expect(!created)
        #expect(try context.fetchCount(FetchDescriptor<UserSettings>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<TaskCategory>()) == 3)
        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.firstLaunchAt == now)  // set once
    }

    @Test func aRenamedOrArchivedDefaultIsNotReseeded() throws {
        let context = try makeContext()
        _ = try Seeding.ensureSeeded(in: context, now: now)
        let family = try #require(try context.fetch(FetchDescriptor<TaskCategory>()).first { $0.presetKey == "family" })
        family.name = "Household"
        family.isArchived = true

        _ = try Seeding.ensureSeeded(in: context, now: now)
        let all = try context.fetch(FetchDescriptor<TaskCategory>())
        #expect(all.count == 3)
        #expect(all.first { $0.presetKey == "family" }?.name == "Household")
    }

    @Test func existingSettingsAreLeftAlone() throws {
        let context = try makeContext()
        let settings = UserSettings()
        settings.mediumDayMinutes = 240
        context.insert(settings)
        _ = try Seeding.ensureSeeded(in: context, now: now)
        #expect(try context.fetchCount(FetchDescriptor<UserSettings>()) == 1)
        #expect(settings.mediumDayMinutes == 240)
        #expect(settings.firstLaunchAt == nil)  // not the first launch of this row
    }

    @Test func userCreatedCategoriesDoNotBlockSeeding() throws {
        let context = try makeContext()
        context.insert(TaskCategory(name: "Errands"))
        _ = try Seeding.ensureSeeded(in: context, now: now)
        #expect(try context.fetchCount(FetchDescriptor<TaskCategory>()) == 4)
    }
}
