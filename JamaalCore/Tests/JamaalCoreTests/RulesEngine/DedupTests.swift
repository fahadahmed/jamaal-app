import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The dedup keys of docs/schema/overview.md. CloudKit can't enforce uniqueness, so two devices
/// can each create the same thing; every rule must be safe to apply repeatedly and in any order.
@MainActor
struct DedupTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeContext() throws -> ModelContext {
        ModelContext(try JamaalSchema.makeContainer(inMemory: true))
    }

    private func day(_ d: Int) -> Date { CalendarDate(year: 2026, month: 10, day: d)!.storedDate }
    private func at(_ seconds: Double) -> Date { now.addingTimeInterval(seconds) }

    // MARK: UserSettings

    @Test func keepsTheEarliestSettingsRowAndMergesFirstLaunchAndOnboarding() throws {
        let context = try makeContext()
        let early = UserSettings(); early.createdAt = at(0); early.firstLaunchAt = nil
        let late = UserSettings(); late.createdAt = at(100); late.firstLaunchAt = at(90); late.onboardingCompletedAt = at(500)
        context.insert(early); context.insert(late)

        let report = try Dedup.run(in: context, now: now)
        let rows = try context.fetch(FetchDescriptor<UserSettings>())
        #expect(rows.count == 1)
        #expect(rows.first?.id == early.id)
        #expect(rows.first?.firstLaunchAt == at(90))          // the survivor inherits what it lacked
        #expect(rows.first?.onboardingCompletedAt == at(500))
        #expect(report.removed == 1)
    }

    // MARK: TaskCategory

    @Test func mergesDefaultCategoriesByPresetKeyAndMovesTheirTasks() throws {
        let context = try makeContext()
        let first = TaskCategory(name: "Work"); first.presetKey = "work"; first.createdAt = at(0)
        let second = TaskCategory(name: "Work"); second.presetKey = "work"; second.createdAt = at(10)
        context.insert(first); context.insert(second)
        let task = TaskItem(title: "Reply")
        context.insert(task)
        task.category = second

        _ = try Dedup.run(in: context, now: now)
        let categories = try context.fetch(FetchDescriptor<TaskCategory>())
        #expect(categories.count == 1)
        #expect(categories.first?.id == first.id)
        #expect(task.category?.id == first.id)
    }

    @Test func mergesUserCategoriesByNormalisedName() throws {
        let context = try makeContext()
        let a = TaskCategory(name: "Errands"); a.createdAt = at(0)
        let b = TaskCategory(name: "  errands "); b.createdAt = at(5)
        let other = TaskCategory(name: "Garden"); other.createdAt = at(6)
        context.insert(a); context.insert(b); context.insert(other)
        let task = TaskItem(); context.insert(task); task.category = b

        _ = try Dedup.run(in: context, now: now)
        #expect(try context.fetchCount(FetchDescriptor<TaskCategory>()) == 2)
        #expect(task.category?.id == a.id)
    }

    @Test func aPresetCategoryAndAUserCategoryWithTheSameNameStaySeparate() throws {
        let context = try makeContext()
        let preset = TaskCategory(name: "Work"); preset.presetKey = "work"
        let user = TaskCategory(name: "Work")
        context.insert(preset); context.insert(user)
        _ = try Dedup.run(in: context, now: now)
        #expect(try context.fetchCount(FetchDescriptor<TaskCategory>()) == 2)
    }

    // MARK: Repeating tasks

    @Test func keepsOneNextInstancePerSeriesAndDueDate() throws {
        let context = try makeContext()
        let series = UUID()
        let a = TaskItem(title: "Water plants", dueDate: day(5)); a.seriesID = series; a.createdAt = at(0)
        let b = TaskItem(title: "Water plants", dueDate: day(5)); b.seriesID = series; b.createdAt = at(3)
        let nextDay = TaskItem(title: "Water plants", dueDate: day(6)); nextDay.seriesID = series
        let plain1 = TaskItem(title: "Call", dueDate: day(5))
        let plain2 = TaskItem(title: "Call", dueDate: day(5))
        for t in [a, b, nextDay, plain1, plain2] { context.insert(t) }

        _ = try Dedup.run(in: context, now: now)
        let ids = Set(try context.fetch(FetchDescriptor<TaskItem>()).map(\.id))
        #expect(ids == [a.id, nextDay.id, plain1.id, plain2.id])  // non-repeating tasks are never merged
    }

    // MARK: DeferralRecord

    @Test func oneDeferralPerTaskPerDayRefinedToTheLatestChoice() throws {
        let context = try makeContext()
        let task = TaskItem(title: "Groceries"); task.deferralCount = 2
        context.insert(task)
        let auto = DeferralRecord(); auto.day = day(5); auto.deferredOn = at(0); auto.reason = "unspecified"; auto.deferredTo = day(6)
        let chosen = DeferralRecord(); chosen.day = day(5); chosen.deferredOn = at(60); chosen.reason = "tooMuch"; chosen.deferredTo = day(8)
        let other = DeferralRecord(); other.day = day(4); other.deferredOn = at(-100)
        for r in [auto, chosen, other] { context.insert(r); r.task = task }

        _ = try Dedup.run(in: context, now: now)
        let records = try context.fetch(FetchDescriptor<DeferralRecord>())
        #expect(records.count == 2)
        let merged = try #require(records.first { $0.id == auto.id })   // the earliest stays
        #expect(merged.reason == "tooMuch")                              // refined to the latest choice
        #expect(merged.deferredTo == day(8))
        #expect(task.deferralCount == 1)                                  // the double increment is undone
    }

    // MARK: WorkSession

    @Test func atMostOneLiveSessionTheLaterOneClosesAsAbandonedWithItsTimeLogged() throws {
        let context = try makeContext()
        let first = WorkSession(); first.startedAt = at(-3600)
        let second = WorkSession(); second.startedAt = at(-1800); second.pausedSeconds = 300
        let finished = WorkSession(); finished.startedAt = at(-9000); finished.endedAt = at(-8000); finished.outcome = "finished"
        for s in [first, second, finished] { context.insert(s) }

        let report = try Dedup.run(in: context, now: now)
        #expect(first.endedAt == nil)
        #expect(first.outcome == "running")
        #expect(second.outcome == "abandoned")
        #expect(second.endedAt == now)
        #expect(second.actualSeconds == 1800 - 300)                       // elapsed minus pauses
        #expect(finished.outcome == "finished")
        #expect(report.abandonedSessionIDs == [second.id])
    }

    @Test func aPausedLaterSessionLogsTimeOnlyUpToItsPause() throws {
        let context = try makeContext()
        let first = WorkSession(); first.startedAt = at(-3600)
        let second = WorkSession(); second.startedAt = at(-1800); second.pausedAt = at(-600)
        context.insert(first); context.insert(second)
        _ = try Dedup.run(in: context, now: now)
        #expect(second.actualSeconds == 1200)                             // 30 min minus the 10 paused so far
    }

    // MARK: HabitEntry

    @Test func keepsOneEntryPerWindowAndDayWithTheLargerAmount() throws {
        let context = try makeContext()
        let window = HabitTimeWindow(); context.insert(window)
        let a = HabitEntry(); a.date = day(5); a.amount = 3; a.target = 8
        let b = HabitEntry(); b.date = day(5); b.amount = 5; b.target = 8; b.completedAt = nil
        let nextDay = HabitEntry(); nextDay.date = day(6); nextDay.amount = 1
        for e in [a, b, nextDay] { context.insert(e); e.window = window }

        _ = try Dedup.run(in: context, now: now)
        let entries = try context.fetch(FetchDescriptor<HabitEntry>())
        #expect(entries.count == 2)
        #expect(entries.first { $0.date == day(5) }?.amount == 5)
    }

    @Test func aCompletionTimestampSurvivesTheMerge() throws {
        let context = try makeContext()
        let window = HabitTimeWindow(); context.insert(window)
        let a = HabitEntry(); a.date = day(5); a.amount = 8; a.completedAt = at(10)
        let b = HabitEntry(); b.date = day(5); b.amount = 8
        for e in [a, b] { context.insert(e); e.window = window }
        _ = try Dedup.run(in: context, now: now)
        let kept = try #require(try context.fetch(FetchDescriptor<HabitEntry>()).first)
        #expect(kept.completedAt == at(10))
    }

    // MARK: Anchor

    @Test func keepsOneGeneratedAnchorPerRuleDayAndSlot() throws {
        let context = try makeContext()
        let rule = AnchorRule(title: "School run"); context.insert(rule)
        let a = Anchor(); a.occurrenceDate = day(5); a.slotKey = "drop"; a.generatedAt = at(0)
        let b = Anchor(); b.occurrenceDate = day(5); b.slotKey = "drop"; b.generatedAt = at(9)
        let otherSlot = Anchor(); otherSlot.occurrenceDate = day(5); otherSlot.slotKey = "pick"
        for x in [a, b, otherSlot] { context.insert(x); x.rule = rule }
        let oneOffA = Anchor(title: "Dentist"); oneOffA.occurrenceDate = day(5)
        let oneOffB = Anchor(title: "Dentist"); oneOffB.occurrenceDate = day(5)
        context.insert(oneOffA); context.insert(oneOffB)

        _ = try Dedup.run(in: context, now: now)
        let ids = Set(try context.fetch(FetchDescriptor<Anchor>()).map(\.id))
        #expect(ids == [a.id, otherSlot.id, oneOffA.id, oneOffB.id])      // one-offs have no key
    }

    @Test func aDecidedAnchorIsNeverResurrectedAsPending() throws {
        let context = try makeContext()
        let rule = AnchorRule(title: "Bin night"); context.insert(rule)
        let pending = Anchor(); pending.occurrenceDate = day(5); pending.generatedAt = at(0)
        let skipped = Anchor(); skipped.occurrenceDate = day(5); skipped.generatedAt = at(9); skipped.attendanceStatus = "skipped"
        for x in [pending, skipped] { context.insert(x); x.rule = rule }

        _ = try Dedup.run(in: context, now: now)
        let kept = try #require(try context.fetch(FetchDescriptor<Anchor>()).first)
        #expect(kept.id == skipped.id)
        #expect(try context.fetchCount(FetchDescriptor<Anchor>()) == 1)
    }

    // MARK: DayPlan

    @Test func keepsTheDayPlanThatWasConfirmedElseADeterministicOne() throws {
        let context = try makeContext()
        let plain = DayPlan(); plain.date = day(5); plain.completedEffortMinutes = 90
        let confirmed = DayPlan(); confirmed.date = day(5); confirmed.planningCompletedAt = at(10)
        let otherDay = DayPlan(); otherDay.date = day(6)
        for p in [plain, confirmed, otherDay] { context.insert(p) }

        _ = try Dedup.run(in: context, now: now)
        let ids = Set(try context.fetch(FetchDescriptor<DayPlan>()).map(\.id))
        #expect(ids == [confirmed.id, otherDay.id])
    }

    // MARK: NightPlanningSession

    @Test func prefersTheCompleteThenTheFurthestThenTheLatestSession() throws {
        let context = try makeContext()
        let early = NightPlanningSession(); early.forDate = day(5); early.currentStep = "carry"; early.createdAt = at(0)
        let further = NightPlanningSession(); further.forDate = day(5); further.currentStep = "build"; further.createdAt = at(5)
        let complete = NightPlanningSession(); complete.forDate = day(5); complete.currentStep = "review"; complete.isComplete = true; complete.createdAt = at(1)
        let otherDay = NightPlanningSession(); otherDay.forDate = day(6)
        for s in [early, further, complete, otherDay] { context.insert(s) }

        _ = try Dedup.run(in: context, now: now)
        let ids = Set(try context.fetch(FetchDescriptor<NightPlanningSession>()).map(\.id))
        #expect(ids == [complete.id, otherDay.id])
    }

    @Test func furthestStepWinsWhenNeitherIsComplete() throws {
        let context = try makeContext()
        let early = NightPlanningSession(); early.forDate = day(5); early.currentStep = "carry"
        let further = NightPlanningSession(); further.forDate = day(5); further.currentStep = "load"
        context.insert(early); context.insert(further)
        _ = try Dedup.run(in: context, now: now)
        let kept = try #require(try context.fetch(FetchDescriptor<NightPlanningSession>()).first)
        #expect(kept.id == further.id)
    }

    // MARK: Idempotence

    @Test func runningTwiceChangesNothingTheSecondTime() throws {
        let context = try makeContext()
        let a = UserSettings(); a.createdAt = at(0)
        let b = UserSettings(); b.createdAt = at(1)
        let p = DayPlan(); p.date = day(5)
        let q = DayPlan(); q.date = day(5)
        for m in [a, b] as [UserSettings] { context.insert(m) }
        context.insert(p); context.insert(q)

        let first = try Dedup.run(in: context, now: now)
        let second = try Dedup.run(in: context, now: now)
        #expect(first.removed == 2)
        #expect(second.removed == 0)
        #expect(second.abandonedSessionIDs.isEmpty)
    }

    @Test func aCleanStoreIsLeftUntouched() throws {
        let context = try makeContext()
        _ = try Seeding.ensureSeeded(in: context, now: now)
        let report = try Dedup.run(in: context, now: now)
        #expect(report.removed == 0)
    }
}
