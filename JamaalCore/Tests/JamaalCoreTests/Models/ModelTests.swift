import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The 14 models of docs/schema/overview.md: defaults, relationships and delete rules, and the
/// "unknown values are kept" rule through the typed accessors.
@MainActor
struct ModelTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try JamaalSchema.makeContainer(inMemory: true))
    }

    // MARK: Schema

    @Test func schemaHasTheFourteenModels() {
        let names = Set(JamaalSchemaV1.models.map { String(describing: $0) })
        #expect(names == [
            "TaskItem", "TaskCategory", "DeferralRecord", "WorkSession",
            "Habit", "HabitTimeWindow", "HabitEntry", "HabitGroup",
            "Anchor", "AnchorRule", "DayPlan", "NightPlanningSession", "NudgeLog", "UserSettings",
        ])
        #expect(JamaalSchemaV1.models.count == 14)
    }

    @Test func schemaIsVersioned() {
        #expect(JamaalSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(JamaalMigrationPlan.schemas.count == 1)
        #expect(JamaalMigrationPlan.stages.isEmpty)
    }

    // MARK: Defaults (every attribute has one; CloudKit requires it)

    @Test func taskDefaults() {
        let task = TaskItem()
        #expect(task.title == "")
        #expect(task.notes == nil)
        #expect(task.dueDate == nil)
        #expect(task.effortMinutes == nil)
        #expect(task.importance == "low")
        #expect(task.importanceLevel == .low)
        #expect(!task.isCompleted)
        #expect(task.completedAt == nil)
        #expect(task.droppedAt == nil)
        #expect(task.deferralCount == 0)
        #expect(task.repeatKind == "none")
        #expect(task.repeatMode == .off)
        #expect(task.repeatWeekdays == "")
        #expect(task.repeatDayOfMonth == 0)
        #expect(task.seriesID == nil)
        #expect(task.category == nil)
    }

    @Test func categoryDefaults() {
        let category = TaskCategory()
        #expect(category.name == "")
        #expect(category.presetKey == nil)
        #expect(category.preset == nil)
        #expect(category.colorKey == "accent")
        #expect(category.color == .accent)
        #expect(category.sortOrder == 0)
        #expect(!category.isArchived)
    }

    @Test func deferralAndSessionDefaults() {
        let deferral = DeferralRecord()
        #expect(deferral.reason == "unspecified")
        #expect(deferral.reasonKind == .unspecified)
        #expect(deferral.deferredTo == nil)

        let session = WorkSession()
        #expect(session.outcome == "running")
        #expect(session.outcomeKind == .running)
        #expect(session.endedAt == nil)
        #expect(session.pausedSeconds == 0)
        #expect(session.pausedAt == nil)
        #expect(session.estimateMinutes == nil)
        #expect(session.actualSeconds == 0)
        #expect(session.task == nil)
        #expect(session.habitWindow == nil)
    }

    @Test func habitDefaults() {
        let habit = Habit()
        #expect(habit.kind == "binary")
        #expect(habit.habitKind == .binary)
        #expect(habit.frequency == "daily")
        #expect(habit.frequencyKind == .daily)
        #expect(habit.scheduledDays == "1,2,3,4,5,6,7")
        #expect(habit.targetPerWeek == 0)
        #expect(habit.pausesData == "[]")
        #expect(habit.preset == nil)
        #expect(!habit.isArchived)

        let window = HabitTimeWindow()
        #expect(window.startMinute == 0)
        #expect(window.endMinute == 1439)
        #expect(window.target == 1)
        #expect(window.effortMinutes == nil)
        #expect(window.reminderMinute == nil)

        let entry = HabitEntry()
        #expect(entry.target == 1)
        #expect(entry.amount == 0)
        #expect(entry.completedAt == nil)

        let group = HabitGroup()
        #expect(group.title == "")
        #expect(!group.isArchived)
    }

    @Test func anchorDefaults() {
        let anchor = Anchor()
        #expect(anchor.attendanceStatus == "pending")
        #expect(anchor.status == .pending)
        #expect(anchor.slotKey == "")
        #expect(anchor.resolvedAt == nil)
        #expect(anchor.remindBeforeStartMinutes == nil)
        #expect(anchor.remindBeforeEndMinutes == nil)
        #expect(anchor.rule == nil)

        let rule = AnchorRule()
        #expect(rule.sourceKey == "custom")
        #expect(rule.source == .custom)
        #expect(rule.configData == "{}")
        #expect(rule.placement == "fixed")
        #expect(rule.placementKind == .fixed)
        #expect(rule.isEnabled)
        #expect(!rule.isArchived)
    }

    @Test func planningAndSettingsDefaults() {
        let plan = DayPlan()
        #expect(plan.capacity == "medium")
        #expect(plan.capacityLevel == .medium)
        #expect(plan.plannedTaskMinutes == 0)
        #expect(plan.loadScore == 0)
        #expect(!plan.wasOverloaded)
        #expect(plan.completionRate == 0)
        #expect(plan.planningCompletedAt == nil)

        let session = NightPlanningSession()
        #expect(session.currentStep == "review")
        #expect(session.step == .review)
        #expect(!session.isComplete)
        #expect(session.skippedAt == nil)
        #expect(session.completedAt == nil)
        #expect(!session.isShortened)

        let nudge = NudgeLog()
        #expect(nudge.kind == "")
        #expect(nudge.nudgeKind == .unknown)
        #expect(nudge.subjectKey == nil)
        #expect(nudge.dismissedAt == nil)

        let settings = UserSettings()
        #expect(settings.mediumDayMinutes == 180)
        #expect(settings.dayStartMinute == 480)
        #expect(settings.dayEndMinute == 1140)
        #expect(settings.rolloverMinute == 0)
        #expect(settings.weekdayLevels == #"{"6":"low","7":"low"}"#)
        #expect(settings.planningMinute == 1200)
        #expect(settings.morningMinute == 480)
        #expect(settings.onboardingCompletedAt == nil)
        #expect(settings.firstLaunchAt == nil)
    }

    @Test func everyModelGetsItsOwnIdentity() {
        #expect(TaskItem().id != TaskItem().id)
        #expect(Anchor().id != Anchor().id)
    }

    // MARK: Typed accessors and the unknown-value rule

    @Test func settingATypedValueWritesTheRawString() {
        let task = TaskItem()
        task.importanceLevel = .high
        #expect(task.importance == "high")
        task.repeatMode = .weekly
        #expect(task.repeatKind == "weekly")
    }

    @Test func anUnknownStoredValueIsKeptNotOverwritten() {
        let task = TaskItem()
        task.importance = "critical"            // written by a newer app
        #expect(task.importanceLevel == .unknown)
        task.importanceLevel = .unknown          // an older app "writes back" what it read
        #expect(task.importance == "critical")   // still intact
        task.importanceLevel = .medium           // a deliberate change replaces it
        #expect(task.importance == "medium")
    }

    @Test func categoryPresetIsOptionalAndTolerant() {
        let category = TaskCategory()
        category.preset = .family
        #expect(category.presetKey == "family")
        category.preset = nil
        #expect(category.presetKey == nil)
        category.presetKey = "somethingNew"
        #expect(category.preset == .unknown)
    }

    // MARK: Relationships and delete rules

    @Test func deletingATaskCascadesToItsDeferralsAndSessions() throws {
        let context = try makeContext()
        let task = TaskItem(title: "Draft")
        context.insert(task)
        let deferral = DeferralRecord()
        let session = WorkSession()
        deferral.task = task
        session.task = task
        context.insert(deferral)
        context.insert(session)
        try context.save()
        #expect(task.deferrals?.count == 1)
        #expect(task.sessions?.count == 1)

        context.delete(task)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<DeferralRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkSession>()) == 0)
    }

    @Test func deletingACategoryKeepsItsTasks() throws {
        let context = try makeContext()
        let category = TaskCategory(name: "Work")
        let task = TaskItem(title: "Reply")
        context.insert(category)
        context.insert(task)
        task.category = category
        try context.save()
        #expect(category.tasks?.count == 1)

        context.delete(category)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 1)
        #expect(task.category == nil)
    }

    @Test func deletingAHabitCascadesThroughWindowsToEntriesAndSessions() throws {
        let context = try makeContext()
        let habit = Habit(title: "Read")
        let window = HabitTimeWindow()
        let entry = HabitEntry()
        let session = WorkSession()
        context.insert(habit)
        context.insert(window)
        context.insert(entry)
        context.insert(session)
        window.habit = habit
        entry.window = window
        session.habitWindow = window
        try context.save()
        #expect(habit.windows?.count == 1)
        #expect(window.entries?.count == 1)
        #expect(window.sessions?.count == 1)

        context.delete(habit)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<HabitTimeWindow>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HabitEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkSession>()) == 0)
    }

    @Test func deletingAGroupKeepsItsHabits() throws {
        let context = try makeContext()
        let group = HabitGroup(title: "Morning")
        let habit = Habit(title: "Water")
        context.insert(group)
        context.insert(habit)
        habit.group = group
        try context.save()
        #expect(group.habits?.count == 1)

        context.delete(group)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Habit>()) == 1)
        #expect(habit.group == nil)
    }

    @Test func deletingARuleKeepsItsAnchorsAsOneOffs() throws {
        let context = try makeContext()
        let rule = AnchorRule(title: "School run")
        let anchor = Anchor(title: "Drop-off")
        context.insert(rule)
        context.insert(anchor)
        anchor.rule = rule
        try context.save()
        #expect(rule.anchors?.count == 1)

        context.delete(rule)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Anchor>()) == 1)
        #expect(anchor.rule == nil)
    }

    // MARK: Persistence

    @Test func valuesSurviveASaveAndFetch() throws {
        let context = try makeContext()
        let day = try #require(CalendarDate(year: 2026, month: 10, day: 1)).storedDate
        let task = TaskItem(title: "Book swimming", dueDate: day, effortMinutes: 30)
        task.importanceLevel = .medium
        context.insert(task)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(fetched.title == "Book swimming")
        #expect(fetched.dueDate == day)
        #expect(fetched.effortMinutes == 30)
        #expect(fetched.importanceLevel == .medium)
    }
}

/// CloudKit sync forbids unique constraints and non-optional relationships, and needs an
/// inverse on every relationship (CLAUDE.md, "SwiftData / CloudKit constraints").
@MainActor
struct CloudKitConstraintTests {

    private var entities: [Schema.Entity] { JamaalSchema.current.entities }

    @Test func noEntityHasAUniquenessConstraint() {
        for entity in entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name) has a unique constraint")
        }
    }

    @Test func everyRelationshipIsOptionalWithAnInverse() {
        for entity in entities {
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name) must be optional")
                #expect(relationship.inverseName != nil, "\(entity.name).\(relationship.name) needs an inverse")
            }
        }
    }

    @Test func thereAreEightRelationshipPairs() {
        // The manifest's 8 relationships each have a forward and an inverse side: 16 attributes.
        #expect(entities.flatMap(\.relationships).count == 16)
    }
}
