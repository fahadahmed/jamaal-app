import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// First launch and onboarding (docs/journeys/onboarding.md). Thu 15 Oct 2026, UTC.
@MainActor
struct OnboardingTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }

    private func world() throws -> (ModelContext, UserSettings) {
        let context = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        try Seeding.ensureSeeded(in: context, now: at(15, 9))
        return (context, try #require(try context.fetch(FetchDescriptor<UserSettings>()).first))
    }

    // MARK: Whether and in what order

    @Test func onboardingShowsUntilItIsCompletedAndNeverWithoutASettingsRow() throws {
        let (_, settings) = try world()
        #expect(Onboarding.isNeeded(settings))
        #expect(!Onboarding.isNeeded(nil))
        Onboarding.complete(settings, now: at(15, 10))
        #expect(!Onboarding.isNeeded(settings))
    }

    @Test func aSecondDeviceThatSyncedAnOldCompletionSkipsIt() throws {
        let (_, settings) = try world()
        settings.onboardingCompletedAt = at(1, 8)                        // arrived from the account
        #expect(!Onboarding.isNeeded(settings))
    }

    @Test func completingKeepsTheFirstDate() throws {
        let (_, settings) = try world()
        Onboarding.complete(settings, now: at(15, 10))
        Onboarding.complete(settings, now: at(16, 10))
        #expect(settings.onboardingCompletedAt == at(15, 10))
    }

    @Test func theStepsRunInOrderAndTheICloudStepOnlyAppearsWhenICloudIsNot() {
        #expect(Onboarding.steps(icloudAvailable: true) == [.meet, .idea, .normalDay, .reminders, .task, .habit, .anchor, .ready])
        #expect(Onboarding.steps(icloudAvailable: false) == [.meet, .idea, .icloud, .normalDay, .reminders, .task, .habit, .anchor, .ready])
        #expect(Onboarding.next(after: .idea, icloudAvailable: true) == .normalDay)
        #expect(Onboarding.next(after: .idea, icloudAvailable: false) == .icloud)
        #expect(Onboarding.next(after: .icloud, icloudAvailable: false) == .normalDay)
        #expect(Onboarding.next(after: .ready, icloudAvailable: true) == nil)
        #expect(Onboarding.previous(before: .normalDay, icloudAvailable: true) == .idea)
        #expect(Onboarding.previous(before: .normalDay, icloudAvailable: false) == .icloud)
        #expect(Onboarding.previous(before: .meet, icloudAvailable: true) == nil)
        #expect(Onboarding.next(after: .icloud, icloudAvailable: true) == nil)          // not a step in that order
    }

    @Test func onlyRemindersAndTheAnchorMayBeSkipped() {
        #expect(OnboardingStep.allCases.filter(\.isSkippable) == [.reminders, .anchor])
    }

    // MARK: Your normal day

    @Test func theNormalDayTheDayEndAndTodaysLevelAreSavedTogether() throws {
        let (context, settings) = try world()
        try Onboarding.saveNormalDay(minutes: 150, dayEnd: 20 * 60, level: .high, settings: settings, in: context, now: at(15, 9), timeZone: utc)
        #expect(settings.mediumDayMinutes == 150 && settings.dayEndMinute == 1200 && settings.dayStartMinute == 480)
        let plan = try #require(try context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.capacityLevel == .high && plan.planningCompletedAt == nil && plan.plannedTaskMinutes == 0)
        #expect(settings.defaultLevel(forISOWeekday: 4) == .medium)                      // the weekday defaults are untouched
        #expect(settings.defaultLevel(forISOWeekday: 6) == .low)
    }

    @Test func aRefusedNormalDayWritesNothingAtAll() throws {
        let (context, settings) = try world()
        #expect(throws: SettingsError.normalDayOutOfRange) {
            try Onboarding.saveNormalDay(minutes: 200, dayEnd: 1200, level: .low, settings: settings, in: context, now: at(15, 9), timeZone: utc)
        }
        #expect(throws: SettingsError.workingDayInvalid) {                                // ends less than two hours after 08:00
            try Onboarding.saveNormalDay(minutes: 120, dayEnd: 9 * 60 + 59, level: .low, settings: settings, in: context, now: at(15, 9), timeZone: utc)
        }
        #expect(settings.mediumDayMinutes == 180 && settings.dayEndMinute == 1140)
        #expect(try context.fetchCount(FetchDescriptor<DayPlan>()) == 0)
        try Onboarding.saveNormalDay(minutes: 120, dayEnd: 10 * 60, level: .low, settings: settings, in: context, now: at(15, 9), timeZone: utc)   // exactly two hours
        #expect(settings.dayEndMinute == 600)
    }

    // MARK: When to speak

    @Test func theTimesAreSyncedOnTheSettingsRow() throws {
        let (_, settings) = try world()
        try Onboarding.saveTimes(planning: 21 * 60, morning: 7 * 60 + 30, settings: settings)
        #expect(settings.planningMinute == 1260 && settings.morningMinute == 450)
        #expect(throws: OnboardingError.timeOutOfRange) { try Onboarding.saveTimes(planning: 1440, morning: 450, settings: settings) }
        #expect(throws: OnboardingError.timeOutOfRange) { try Onboarding.saveTimes(planning: 1200, morning: -1, settings: settings) }
        #expect(settings.planningMinute == 1260)
    }

    // MARK: The first task

    @Test func theFirstTaskIsLowImportanceAndDueTodayOrTomorrow() throws {
        let (context, _) = try world()
        let personal = try #require(try context.fetch(FetchDescriptor<TaskCategory>()).first { $0.presetKey == "personal" })
        let today = try Onboarding.createFirstTask(title: "  Call the clinic back ", category: personal, day: .today, in: context, now: at(15, 9), timeZone: utc)
        #expect(today.title == "Call the clinic back" && today.importanceLevel == .low)
        #expect(today.dueDate == d(15).storedDate && today.category === personal)
        let tomorrow = try Onboarding.createFirstTask(title: "Book the dentist", category: nil, day: .tomorrow, in: context, now: at(15, 9), timeZone: utc)
        #expect(tomorrow.dueDate == d(16).storedDate && tomorrow.category == nil)
    }

    @Test func aBlankFirstTaskIsRefused() throws {
        let (context, _) = try world()
        #expect(throws: TaskCreationError.emptyTitle) {
            try Onboarding.createFirstTask(title: "  ", category: nil, day: .today, in: context, now: at(15, 9), timeZone: utc)
        }
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }

    @Test func theFirstTaskFollowsTheRolloverWhenItIsLate() throws {
        let (context, settings) = try world()
        settings.rolloverMinute = 180
        let task = try Onboarding.createFirstTask(title: "Late", category: nil, day: .today, in: context, now: at(16, 1), timeZone: utc)   // 01:00 is still the 15th
        #expect(task.dueDate == d(15).storedDate)
    }

    // MARK: The first habit

    @Test func theChoicesAreTheFramesFiveInOrder() {
        #expect(Onboarding.habitChoices.map(\.title) == ["Qur'an reading", "Water", "A walk", "Dhikr", "Something else"])
        #expect(Onboarding.habitChoices.map(\.subtitle) == ["15 minutes a day", "8 glasses a day", "20 minutes, three times a week", "33 a day", "Just a name, once a day"])
        #expect(Onboarding.habitChoices.filter(\.needsName).map(\.id) == ["other"])
    }

    @Test func eachChoiceMakesTheHabitItDescribes() throws {
        let (context, _) = try world()
        let quran = try Onboarding.createFirstHabit(choice: "quran", in: context, now: at(15, 9))
        #expect(quran.title == "Qur'an reading" && quran.habitKind == .timed && quran.presetKey == "quran")
        let water = try Onboarding.createFirstHabit(choice: "water", in: context, now: at(15, 9))
        #expect(water.habitKind == .counted && water.presetKey == nil && water.windows?.first?.target == 8)
        let walk = try Onboarding.createFirstHabit(choice: "walk", in: context, now: at(15, 9))
        #expect(walk.habitKind == .timed && walk.targetPerWeek == 3 && walk.windows?.first?.target == 20)
        let dhikr = try Onboarding.createFirstHabit(choice: "dhikr", in: context, now: at(15, 9))
        #expect(dhikr.habitKind == .counted && dhikr.windows?.first?.target == 33)
        let other = try Onboarding.createFirstHabit(choice: "other", name: "Stretch", in: context, now: at(15, 9))
        #expect(other.habitKind == .binary && other.title == "Stretch" && (other.windows?.count ?? 0) == 1)
    }

    @Test func aBareHabitNeedsAName() throws {
        let (context, _) = try world()
        #expect(throws: HabitEditError.emptyTitle) { try Onboarding.createFirstHabit(choice: "other", name: " ", in: context, now: at(15, 9)) }
        #expect(throws: OnboardingError.notAFirstHabit) { try Onboarding.createFirstHabit(choice: "nonsense", in: context, now: at(15, 9)) }
        #expect(try context.fetchCount(FetchDescriptor<Habit>()) == 0)
    }

    // MARK: The first Today

    @Test func tonightWeWillPlanTomorrowShowsOnlyOnTheDayOnboardingFinishedUntilPlanned() throws {
        let (context, settings) = try world()
        #expect(try !Onboarding.tonightCardVisible(settings: settings, now: at(15, 11), boundary: boundary, context: context))   // not finished
        Onboarding.complete(settings, now: at(15, 10))
        #expect(try Onboarding.tonightCardVisible(settings: settings, now: at(15, 11), boundary: boundary, context: context))
        #expect(try !Onboarding.tonightCardVisible(settings: settings, now: at(16, 8), boundary: boundary, context: context))     // the next day
        let session = NightPlanningSession(); session.forDate = d(16).storedDate; context.insert(session)
        #expect(try !Onboarding.tonightCardVisible(settings: settings, now: at(15, 21), boundary: boundary, context: context))    // already planning
        #expect(try !Onboarding.tonightCardVisible(settings: nil, now: at(15, 21), boundary: boundary, context: context))
    }

    @Test func aSessionForSomeOtherDateDoesNotHideTheCard() throws {
        let (context, settings) = try world()
        Onboarding.complete(settings, now: at(15, 10))
        let other = NightPlanningSession(); other.forDate = d(20).storedDate; context.insert(other)
        #expect(try Onboarding.tonightCardVisible(settings: settings, now: at(15, 11), boundary: boundary, context: context))
    }
}
