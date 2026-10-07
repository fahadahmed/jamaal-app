import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Export my data and Delete my data (ST-08).
@MainActor
struct DataExportTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func at(_ day: Int, _ hour: Int = 9) -> Date { boundary.instant(of: CalendarDate(year: 2026, month: 10, day: day)!, atMinute: hour * 60) }

    /// A little of everything, linked.
    private func populated() throws -> ModelContext {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        try Seeding.ensureSeeded(in: c, now: at(1))
        let work = try #require(try c.fetch(FetchDescriptor<TaskCategory>()).first { $0.presetKey == "work" })
        let task = try TaskCreation.create({ var d = TaskDraft(title: "Draft"); d.dueDate = CalendarDate(year: 2026, month: 10, day: 15); d.category = work; return d }(), in: c, now: at(14))
        let session = WorkSession(); session.startedAt = at(15); session.day = at(15); session.task = task; c.insert(session)
        let deferral = DeferralRecord(); deferral.task = task; c.insert(deferral)
        var habit = HabitDraft(kind: .counted); habit.title = "Water"; habit.windows[0].target = 8
        let water = try HabitEditing.create(habit, in: c, now: at(1))
        let window = try #require(water.windows?.first)
        let entry = HabitEntry(); entry.window = window; entry.date = at(15); entry.amount = 3; c.insert(entry)
        var salah = PrayerRuleDraft(countryCode: "GB"); salah.location = PrayerConfig.Location(mode: "manual", latitude: 52.64, longitude: -1.14, name: "Leicester")
        let rule = try PrayerEditing.create(salah, in: c, now: at(1))
        let anchor = Anchor(title: "Asr"); anchor.rule = rule; c.insert(anchor)
        let plan = DayPlan(); plan.date = at(15); c.insert(plan)
        let night = NightPlanningSession(); night.forDate = at(16); c.insert(night)
        let nudge = NudgeLog(); nudge.kind = "wellbeing"; c.insert(nudge)
        _ = try HabitEditing.createGroup(named: "Morning", in: c)
        try c.save()
        return c
    }

    private func parse(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Export

    @Test func theFileHasTheAppTheFormatTheTimeAndEveryModelsCount() throws {
        let c = try populated()
        let doc = try parse(try DataExport.json(in: c, now: at(20)))
        #expect(doc["app"] as? String == "Jamaal" && doc["format"] as? Int == 1)
        #expect((doc["exportedAt"] as? String)?.hasPrefix("2026-10-20T09:00:00") == true)
        let counts = try #require(doc["counts"] as? [String: Int])
        #expect(counts["TaskItem"] == 1 && counts["TaskCategory"] == 3 && counts["UserSettings"] == 1)
        #expect(counts["Habit"] == 1 && counts["HabitTimeWindow"] == 1 && counts["HabitEntry"] == 1 && counts["HabitGroup"] == 1)
        #expect(counts["AnchorRule"] == 1 && counts["Anchor"] == 1 && counts["WorkSession"] == 1 && counts["DeferralRecord"] == 1)
        #expect(counts["DayPlan"] == 1 && counts["NightPlanningSession"] == 1 && counts["NudgeLog"] == 1)
    }

    @Test func everyModelInTheSchemaIsExportedWithEveryOneOfItsFields() throws {
        let c = try populated()
        let tables = try DataExport.records(in: c)
        let entities = JamaalSchema.current.entities
        #expect(Set(tables.keys) == Set(entities.map(\.name)))
        for entity in entities {
            let row = try #require(tables[entity.name]?.first, "\(entity.name) has a row")
            // Every stored attribute is written under its own name; every to-one link as <name>ID; to-many links live on the other side.
            var expected = Set(entity.attributes.map(\.name))
            expected.insert("id")
            for relationship in entity.relationships where relationship.isToOneRelationship { expected.insert(relationship.name + "ID") }
            #expect(Set(row.keys) == expected, "\(entity.name): \(Set(row.keys).symmetricDifference(expected))")
        }
    }

    @Test func valuesAreWrittenAsTextNumbersAndLinks() throws {
        let c = try populated()
        let tables = try DataExport.records(in: c)
        let task = try #require(tables["TaskItem"]?.first)
        #expect(task["title"] as? String == "Draft" && task["effortMinutes"] as? Int == 30 && task["isCompleted"] as? Bool == false)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let due = try #require((task["dueDate"] as? String).flatMap(formatter.date(from:)))      // real ISO 8601, and it reads back as the same day
        #expect(CalendarDate(storedDate: due) == CalendarDate(year: 2026, month: 10, day: 15))
        #expect(task["notes"] is NSNull)                                                       // absent is null, never missing
        let work = try #require(tables["TaskCategory"]?.first { $0["presetKey"] as? String == "work" })
        #expect(task["categoryID"] as? String == work["id"] as? String)
        let session = try #require(tables["WorkSession"]?.first)
        #expect(session["taskID"] as? String == task["id"] as? String && session["habitWindowID"] is NSNull)
        let entry = try #require(tables["HabitEntry"]?.first)
        let window = try #require(tables["HabitTimeWindow"]?.first)
        #expect(entry["windowID"] as? String == window["id"] as? String && entry["amount"] as? Int == 3)
        let anchor = try #require(tables["Anchor"]?.first)
        #expect(anchor["ruleID"] as? String == tables["AnchorRule"]?.first?["id"] as? String)
        let rule = try #require(tables["AnchorRule"]?.first)
        #expect((rule["configData"] as? String)?.contains("Leicester") == true)               // the config travels as it is stored
    }

    @Test func theFileIsStableAndKeySortedSoTwoExportsOfTheSameDataMatch() throws {
        let c = try populated()
        let a = try DataExport.json(in: c, now: at(20))
        let b = try DataExport.json(in: c, now: at(20))
        #expect(a == b)
        let text = try #require(String(data: a, encoding: .utf8))
        #expect(text.contains("\"app\" : \"Jamaal\""))
    }

    @Test func rowsAreInAStableOrderByTheirIds() throws {
        let c = try populated()
        for n in 0..<6 { _ = try TaskCreation.create(TaskDraft(title: "Extra \(n)"), in: c, now: at(14)) }
        let ids = try #require(try DataExport.records(in: c)["TaskItem"]).compactMap { $0["id"] as? String }
        #expect(ids.count == 7 && ids == ids.sorted())
    }

    @Test func anEmptyStoreStillExportsAValidFileWithEveryModelEmpty() throws {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        let doc = try parse(try DataExport.json(in: c, now: at(20)))
        let counts = try #require(doc["counts"] as? [String: Int])
        #expect(counts.count == JamaalSchema.current.entities.count && counts.values.allSatisfy { $0 == 0 })
    }

    // MARK: Delete

    @Test func deletingEverythingLeavesNothingAndTheAppStartsAgainAtOnboarding() throws {
        let c = try populated()
        let settings = try #require(try c.fetch(FetchDescriptor<UserSettings>()).first)
        Onboarding.complete(settings, now: at(2))
        try DataReset.deleteEverything(in: c)
        let counts = try DataExport.records(in: c).mapValues(\.count)
        #expect(counts.values.allSatisfy { $0 == 0 }, "\(counts)")
        try Seeding.ensureSeeded(in: c, now: at(21))                                          // what the next launch does
        let fresh = try #require(try c.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(Onboarding.isNeeded(fresh) && fresh.firstLaunchAt == at(21))
        #expect(try c.fetchCount(FetchDescriptor<TaskCategory>()) == 3 && (try c.fetchCount(FetchDescriptor<TaskItem>())) == 0)
    }

    @Test func deletingFromAnEmptyStoreIsHarmless() throws {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        try DataReset.deleteEverything(in: c)
        #expect(try DataExport.records(in: c).values.allSatisfy { $0.isEmpty })
    }
}
