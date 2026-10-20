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
        _ = try Seeding.ensureSeeded(in: context, now: now, startsTrial: false)
        #expect(try context.fetchCount(FetchDescriptor<UserSettings>()) == 1)
        #expect(settings.mediumDayMinutes == 240)
        #expect(settings.firstLaunchAt == nil)  // a beta doesn't start the trial on an existing row either
        _ = try Seeding.ensureSeeded(in: context, now: now)
        #expect(settings.mediumDayMinutes == 240, "only the trial start is ever filled in")
        #expect(settings.firstLaunchAt == now, "a build that starts the trial claims it, once")
    }

    @Test func userCreatedCategoriesDoNotBlockSeeding() throws {
        let context = try makeContext()
        context.insert(TaskCategory(name: "Errands"))
        _ = try Seeding.ensureSeeded(in: context, now: now)
        #expect(try context.fetchCount(FetchDescriptor<TaskCategory>()) == 4)
    }

    // MARK: The trial's start (#291)

    /// A TestFlight beta shares the production iCloud container with the App Store release, and `firstLaunchAt` syncs. If a beta
    /// build set it, a tester's 14-day trial would already be over on the release's first launch.
    @Test func aBetaBuildSeedsSettingsWithoutStartingTheTrial() throws {
        let context = try makeContext()
        _ = try Seeding.ensureSeeded(in: context, now: now, startsTrial: false)
        let settings = try #require(try context.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(settings.firstLaunchAt == nil)
        #expect(try context.fetchCount(FetchDescriptor<TaskCategory>()) == 3, "everything else is seeded as usual")
    }

    @Test func aBetaBuildNeverStartsItOnLaterLaunchesEither() throws {
        let context = try makeContext()
        _ = try Seeding.ensureSeeded(in: context, now: now, startsTrial: false)
        _ = try Seeding.ensureSeeded(in: context, now: now.addingTimeInterval(86_400 * 20), startsTrial: false)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.firstLaunchAt == nil)
    }

    @Test func theFirstLaunchOfARealBuildAfterABetaStartsTheTrialOnceThatDay() throws {
        let context = try makeContext()
        _ = try Seeding.ensureSeeded(in: context, now: now, startsTrial: false)                       // weeks of beta
        let release = now.addingTimeInterval(86_400 * 30)
        _ = try Seeding.ensureSeeded(in: context, now: release, startsTrial: true)                    // the App Store build
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.firstLaunchAt == release)
        _ = try Seeding.ensureSeeded(in: context, now: release.addingTimeInterval(86_400 * 3), startsTrial: true)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.firstLaunchAt == release, "set once")
    }

    @Test func aRealBuildNeverMovesATrialStartThatIsAlreadySet() throws {
        let context = try makeContext()
        _ = try Seeding.ensureSeeded(in: context, now: now)
        _ = try Seeding.ensureSeeded(in: context, now: now.addingTimeInterval(86_400 * 9), startsTrial: true)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.firstLaunchAt == now)
    }

    @Test func theEngineTickPassesItThrough() throws {
        let context = try makeContext()
        _ = try EngineTick.run(in: context, now: now, timeZone: TimeZone(identifier: "UTC")!, lastProcessed: nil, startsTrial: false)
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.firstLaunchAt == nil)
    }
}
