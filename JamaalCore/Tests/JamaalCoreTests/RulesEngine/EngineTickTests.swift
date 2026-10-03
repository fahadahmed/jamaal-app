import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The engine tick: everything the app keeps current on launch and whenever it becomes active, as one
/// idempotent call (seed, dedup, the rollover's catch-up, closing missed Anchor windows, generating
/// Anchors for today and tomorrow). Midnight rollover, UTC, unless a test says otherwise.
@MainActor
struct EngineTickTests {

    private let utc = TimeZone(identifier: "UTC")!
    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        DayBoundary(rolloverMinute: 0, timeZone: utc).instant(of: d(day), atMinute: hour * 60 + minute)
    }
    private func tick(_ c: ModelContext, now: Date, last: CalendarDate? = nil) throws -> EngineTickResult {
        try EngineTick.run(in: c, now: now, timeZone: utc, lastProcessed: last)
    }

    @Test func aFreshStoreIsSeededAndStartsFromYesterday() throws {
        let c = try context()
        let result = try tick(c, now: at(15))
        #expect(result.seeded)
        #expect(try c.fetchCount(FetchDescriptor<UserSettings>()) == 1)
        #expect(try c.fetchCount(FetchDescriptor<TaskCategory>()) == 3)
        #expect(result.lastProcessed == d(14))                                  // a first run has no history to catch up on
        #expect(result.rollover.processedDays.isEmpty)
    }

    @Test func runningTwiceChangesNothingTheSecondTime() throws {
        let c = try context()
        _ = try tick(c, now: at(15))
        let t = TaskItem(title: "Old", dueDate: d(13).storedDate); c.insert(t)
        let first = try tick(c, now: at(16), last: d(14))
        let second = try tick(c, now: at(16), last: first.lastProcessed)
        #expect(!second.seeded)
        #expect(second.dedup.removed == 0)
        #expect(second.rollover.processedDays.isEmpty)
        #expect(second.anchors == AnchorSyncReport())
        #expect(try c.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }

    @Test func theRolloverCatchesUpEveryEndedDaySinceTheLastRun() throws {
        let c = try context()
        _ = try tick(c, now: at(15))
        let t = TaskItem(title: "Groceries", dueDate: d(15).storedDate); c.insert(t)
        let result = try tick(c, now: at(18, 8), last: d(14))                    // 15, 16, 17 have ended
        #expect(result.rollover.processedDays == [d(15), d(16), d(17)])
        #expect(result.lastProcessed == d(17))
        #expect(t.deferralCount == 3)
        #expect(t.dueDate == d(18).storedDate)
    }

    @Test func theUsersRolloverTimeIsRead() throws {
        let c = try context()
        _ = try tick(c, now: at(15))
        let settings = try #require(try c.fetch(FetchDescriptor<UserSettings>()).first)
        settings.rolloverMinute = 180                                            // the day ends at 03:00
        // 01:30 on the 17th is still the 16th, so only the 15th has ended since the 14th.
        let result = try tick(c, now: at(17, 1, 30), last: d(14))
        #expect(result.rollover.processedDays == [d(15)])
    }

    @Test func duplicatesFromAnotherDeviceAreMergedBeforeAnythingReadsThem() throws {
        let c = try context()
        _ = try tick(c, now: at(15))
        let twin = UserSettings(); c.insert(twin)                                // a second device seeded its own
        let personal = TaskCategory(name: "Personal"); personal.presetKey = "personal"; c.insert(personal)
        let result = try tick(c, now: at(15, 10), last: d(14))
        #expect(result.dedup.removed == 2)
        #expect(try c.fetchCount(FetchDescriptor<UserSettings>()) == 1)
        #expect(try c.fetchCount(FetchDescriptor<TaskCategory>()) == 3)
    }

    @Test func missedAnchorWindowsAreClosedAndNewInstancesGenerated() throws {
        let c = try context()
        _ = try tick(c, now: at(15))
        let config = ScheduledConfig(recurrence: .weekly(weekdays: [1, 2, 3, 4, 5]),
                                     slots: [AnchorSlot(id: "drop", label: "Drop-off", start: "08:15", windowMinutes: 30)])
        let rule = AnchorRule(title: "School run"); rule.source = .schoolRun; rule.configData = config.json
        rule.createdAt = at(1, 0); c.insert(rule)
        let result = try tick(c, now: at(15, 9), last: d(14))                    // Thu 15, 09:00: the 08:15 window has closed
        #expect(result.anchors.created == 2)                                      // Thu and Fri
        #expect(result.anchorsFinalised == 1)                                     // Thursday's, never tapped
        let thursday = try #require(try c.fetch(FetchDescriptor<Anchor>()).first { $0.occurrenceDate == d(15).storedDate })
        #expect(thursday.status == .missed)
    }

    @Test func aSecondTickSeesWhatTheFirstGeneratedAndLeavesItBe() throws {
        let c = try context()
        _ = try tick(c, now: at(15))
        let config = ScheduledConfig(recurrence: .weekly(weekdays: [1, 2, 3, 4, 5]),
                                     slots: [AnchorSlot(id: "drop", label: "Drop-off", start: "08:15", windowMinutes: 30)])
        let rule = AnchorRule(title: "School run"); rule.source = .schoolRun; rule.configData = config.json
        rule.createdAt = at(1, 0); c.insert(rule)
        _ = try tick(c, now: at(15, 7), last: d(14))
        let again = try tick(c, now: at(15, 7, 30), last: d(14))
        #expect(again.anchors == AnchorSyncReport())
        #expect(try c.fetchCount(FetchDescriptor<Anchor>()) == 2)
    }
}
