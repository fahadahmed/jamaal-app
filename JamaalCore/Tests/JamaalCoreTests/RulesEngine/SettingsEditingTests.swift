import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Capacity and day (ST-02) and Categories (ST-04).
@MainActor
struct SettingsEditingTests {

    private let utc = TimeZone(identifier: "UTC")!
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }
    private func settings(_ c: ModelContext) -> UserSettings { let s = UserSettings(); c.insert(s); return s }

    // MARK: Normal day

    @Test(arguments: [30, 45, 180, 345, 360])
    func theNormalDayTakesFifteenMinuteStepsFromHalfAnHourToSixHours(_ minutes: Int) throws {
        let s = settings(try context())
        try DaySettings.setNormalDay(minutes, on: s)
        #expect(s.mediumDayMinutes == minutes)
    }

    @Test(arguments: [0, 15, 29, 31, 200, 375, 380, -15])
    func aNormalDayOutsideTheSliderIsRefused(_ minutes: Int) throws {
        let s = settings(try context())
        #expect(throws: SettingsError.normalDayOutOfRange) { try DaySettings.setNormalDay(minutes, on: s) }
        #expect(s.mediumDayMinutes == 180)
    }

    // MARK: Working day

    @Test func theWorkingDayNeedsTwoHoursAndToStartAfterTheRollover() throws {
        let s = settings(try context())
        try DaySettings.setWorkingDay(start: 9 * 60, end: 17 * 60, on: s)
        #expect(s.dayStartMinute == 540 && s.dayEndMinute == 1020)
        try DaySettings.setWorkingDay(start: 9 * 60, end: 11 * 60, on: s)                       // exactly two hours
        for (start, end) in [(540, 659), (540, 540), (600, 500), (-1, 700), (540, 1440), (540, 0)] {
            #expect(throws: SettingsError.workingDayInvalid) { try DaySettings.setWorkingDay(start: start, end: end, on: s) }
        }
        s.rolloverMinute = 180
        #expect(throws: SettingsError.workingDayInvalid) { try DaySettings.setWorkingDay(start: 180, end: 700, on: s) }
        try DaySettings.setWorkingDay(start: 181, end: 700, on: s)
        #expect(s.dayStartMinute == 181)
    }

    // MARK: Rollover (G-54)

    @Test func theRolloverCanChangeOnlyOnceBothTimesHavePassed() throws {
        let s = settings(try context())                                    // rollover 00:00, day starts 08:00
        #expect(DaySettings.rolloverAvailability(s, nowMinute: 9 * 60) == .upTo(360))
        #expect(DaySettings.rolloverAvailability(s, nowMinute: 90) == .upTo(90))
        try DaySettings.setRollover(180, on: s, nowMinute: 9 * 60)
        #expect(s.rolloverMinute == 180)
        #expect(DaySettings.rolloverAvailability(s, nowMinute: 180) == .upTo(180))     // exactly at the rollover: it has passed
        #expect(DaySettings.rolloverAvailability(s, nowMinute: 179) == .after(180))
        // 01:30 with the rollover at 03:00: it is still "yesterday", so nothing can change until 03:00.
        #expect(DaySettings.rolloverAvailability(s, nowMinute: 90) == .after(180))
        #expect(throws: SettingsError.rolloverNotChangeableNow) { try DaySettings.setRollover(0, on: s, nowMinute: 90) }
        // 02:00 with the new value 03:00 not yet passed: refused even though the old one has.
        s.rolloverMinute = 0
        #expect(throws: SettingsError.rolloverNotChangeableNow) { try DaySettings.setRollover(180, on: s, nowMinute: 120) }
        try DaySettings.setRollover(120, on: s, nowMinute: 120)           // exactly now: both give the same date
        #expect(s.rolloverMinute == 120)
    }

    @Test func theRolloverStaysInRangeAndBeforeTheWorkingDay() throws {
        let s = settings(try context())
        #expect(throws: SettingsError.rolloverOutOfRange) { try DaySettings.setRollover(361, on: s, nowMinute: 900) }
        #expect(throws: SettingsError.rolloverOutOfRange) { try DaySettings.setRollover(-1, on: s, nowMinute: 900) }
        s.dayStartMinute = 300
        #expect(throws: SettingsError.workingDayInvalid) { try DaySettings.setRollover(300, on: s, nowMinute: 900) }
        try DaySettings.setRollover(299, on: s, nowMinute: 900)
        #expect(s.rolloverMinute == 299)
    }

    // MARK: Planning note (G-57)

    @Test func theNoteAppearsOnlyWhenPlanningComesBeforeTheDayEnds() throws {
        let s = settings(try context())
        #expect(DaySettings.planningBeforeDayEnd(s) == nil)               // 20:00 planning, 19:00 end
        s.planningMinute = 18 * 60 + 30
        #expect(DaySettings.planningBeforeDayEnd(s) == 1110)
        s.planningMinute = s.dayEndMinute
        #expect(DaySettings.planningBeforeDayEnd(s) == nil)
    }

    // MARK: The normal-day suggestion

    private func plan(_ c: ModelContext, daysAgo: Int, minutes: Int) {
        let p = DayPlan()
        p.date = d(30).addingDays(-daysAgo).storedDate
        p.completedEffortMinutes = minutes
        c.insert(p)
    }

    @Test func theSuggestionIsTheMedianRoundedToFifteenAfterFourteenDaysOfUse() throws {
        let c = try context(); let s = settings(c)
        for i in 0..<13 { plan(c, daysAgo: i, minutes: 160) }
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == nil)        // 13 days: not yet
        plan(c, daysAgo: 13, minutes: 160)
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == nil)        // 160 → 165, within 30 of 180
        s.mediumDayMinutes = 240
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == 165)
        s.mediumDayMinutes = 195                                                                      // exactly 30 away: offered
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == 165)
        s.mediumDayMinutes = 194
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == nil)
    }

    @Test func onlyDaysWithSomeWorkCountAndOnlyTheLastFourWeeks() throws {
        let c = try context(); let s = settings(c); s.mediumDayMinutes = 300
        for i in 0..<14 { plan(c, daysAgo: i, minutes: 120) }
        for i in 14..<28 { plan(c, daysAgo: i, minutes: 0) }              // quiet days are left out of the median
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == 120)
        plan(c, daysAgo: 28, minutes: 360)                                // older than 28 days: ignored
        plan(c, daysAgo: 29, minutes: 360)
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == 120)
        let even = try context(); let s2 = settings(even); s2.mediumDayMinutes = 300
        for i in 0..<7 { plan(even, daysAgo: i, minutes: 100) }
        for i in 7..<14 { plan(even, daysAgo: i, minutes: 130) }
        #expect(try DaySettings.normalDaySuggestion(in: even, settings: s2, today: d(30)) == 120)    // median 115 → 120
    }

    @Test func theSuggestionStaysWithinTheSlidersRange() throws {
        let c = try context(); let s = settings(c); s.mediumDayMinutes = 60
        for i in 0..<14 { plan(c, daysAgo: i, minutes: 500) }
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == 360)
        let low = try context(); let s2 = settings(low); s2.mediumDayMinutes = 120
        for i in 0..<14 { plan(low, daysAgo: i, minutes: 5) }
        #expect(try DaySettings.normalDaySuggestion(in: low, settings: s2, today: d(30)) == 30)
    }

    @Test func aDeclinedSuggestionIsNotOfferedAgainForFourWeeksNorWhenTheSameValueReturns() throws {
        let c = try context(); let s = settings(c); s.mediumDayMinutes = 240
        for i in 0..<14 { plan(c, daysAgo: i, minutes: 165) }
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == 165)
        try DaySettings.logShown(165, in: c, now: d(30).storedDate)
        try DaySettings.logShown(165, in: c, now: d(30).storedDate)
        #expect(try c.fetchCount(FetchDescriptor<NudgeLog>()) == 1)                                 // shown once
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30)) == 165)       // showing doesn't silence it
        try DaySettings.decline(165, in: c, now: d(30).storedDate)
        #expect(try c.fetch(FetchDescriptor<NudgeLog>()).first?.dismissedAt != nil)
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(31)) == nil)       // within 28 days
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(30).addingDays(40)) == nil)   // same value, long after
    }

    @Test func decliningAnyValueQuietensTheLineForFourWeeks() throws {
        let c = try context(); let s = settings(c); s.mediumDayMinutes = 240
        for i in 0..<14 { plan(c, daysAgo: i, minutes: 165) }
        try DaySettings.decline(150, in: c, now: d(30).storedDate)                                  // a different value was declined
        #expect(try DaySettings.normalDaySuggestion(in: c, settings: s, today: d(31)) == nil)
    }

    @Test func decliningWithoutAPriorShowLogsItToo() throws {
        let c = try context()
        try DaySettings.decline(150, in: c, now: .now)
        let logs = try c.fetch(FetchDescriptor<NudgeLog>())
        #expect(logs.count == 1 && logs[0].subjectKey == "150" && logs[0].dismissedAt != nil)
    }

    // MARK: Categories

    private func seeded() throws -> ModelContext {
        let c = try context()
        try Seeding.ensureSeeded(in: c, now: .now)
        return c
    }

    @Test func addingALabelTakesTheNextUnusedColourAndGoesToTheEnd() throws {
        let c = try seeded()
        let errands = try CategoryEditing.add(name: "  Errands ", in: c, now: .now)
        #expect(errands.name == "Errands" && errands.presetKey == nil)
        #expect(errands.color == .plum && errands.sortOrder == 3)                // accent, ochre, blue are taken
        #expect(try CategoryEditing.active(in: c).map(\.name) == ["Personal", "Family", "Work", "Errands"])
        let allotment = try CategoryEditing.add(name: "Allotment", color: .slate, in: c, now: .now)
        #expect(allotment.color == .slate)
    }

    @Test func aNameIsTrimmedShortAndUniqueIgnoringCaseArchivedIncluded() throws {
        let c = try seeded()
        #expect(throws: SettingsError.emptyName) { try CategoryEditing.add(name: "   ", in: c, now: .now) }
        #expect(throws: SettingsError.nameTooLong) { try CategoryEditing.add(name: String(repeating: "x", count: 25), in: c, now: .now) }
        _ = try CategoryEditing.add(name: String(repeating: "x", count: 24), in: c, now: .now)
        #expect(throws: SettingsError.nameTaken) { try CategoryEditing.add(name: "work", in: c, now: .now) }
        let family = try #require(try CategoryEditing.active(in: c).first { $0.name == "Family" })
        CategoryEditing.archive(family)
        #expect(throws: SettingsError.nameTaken) { try CategoryEditing.add(name: "FAMILY", in: c, now: .now) }
    }

    @Test func renamingKeepsAPresetKeyAndRefusesADuplicateButAllowsItsOwnName() throws {
        let c = try seeded()
        let work = try #require(try CategoryEditing.active(in: c).first { $0.name == "Work" })
        try CategoryEditing.rename(work, to: "Job", in: c)
        #expect(work.name == "Job" && work.presetKey == "work")
        try CategoryEditing.rename(work, to: "JOB", in: c)                        // its own name, new case
        #expect(throws: SettingsError.nameTaken) { try CategoryEditing.rename(work, to: "personal", in: c) }
        #expect(throws: SettingsError.emptyName) { try CategoryEditing.rename(work, to: "", in: c) }
        #expect(work.name == "JOB")
    }

    @Test func atMostEightLabelsAreActiveAndArchivingMakesRoom() throws {
        let c = try seeded()
        for i in 0..<5 { _ = try CategoryEditing.add(name: "Label \(i)", in: c, now: .now) }
        #expect(try CategoryEditing.active(in: c).count == 8 && !(try CategoryEditing.canAdd(in: c)))
        #expect(throws: SettingsError.tooManyCategories) { try CategoryEditing.add(name: "One more", in: c, now: .now) }
        let family = try #require(try CategoryEditing.active(in: c).first { $0.name == "Family" })
        CategoryEditing.archive(family)
        #expect(try CategoryEditing.canAdd(in: c))
        let extra = try CategoryEditing.add(name: "One more", in: c, now: .now)
        #expect(throws: SettingsError.tooManyCategories) { try CategoryEditing.restore(family, in: c) }
        CategoryEditing.archive(extra)
        try CategoryEditing.restore(family, in: c)
        #expect(!family.isArchived && family.sortOrder > 4)
        #expect(try CategoryEditing.archived(in: c).map(\.name) == ["One more"])
    }

    @Test func aLabelMovesWithinTheListAndTheOrderIsRenumbered() throws {
        let c = try seeded()
        _ = try CategoryEditing.add(name: "Errands", in: c, now: .now)
        let active = try CategoryEditing.active(in: c)
        try CategoryEditing.move(active[3], to: 0, in: c)
        #expect(try CategoryEditing.active(in: c).map(\.name) == ["Errands", "Personal", "Family", "Work"])
        try CategoryEditing.move(active[3], to: 99, in: c)
        #expect(try CategoryEditing.active(in: c).map(\.name) == ["Personal", "Family", "Work", "Errands"])
        #expect(try CategoryEditing.active(in: c).map(\.sortOrder) == [0, 1, 2, 3])
        let gone = TaskCategory(name: "Elsewhere"); c.insert(gone); gone.isArchived = true
        #expect(throws: SettingsError.notFound) { try CategoryEditing.move(gone, to: 0, in: c) }
    }

    @Test func colourIsOneOfTheFiveAndTasksKeepAnArchivedLabel() throws {
        let c = try seeded()
        let work = try #require(try CategoryEditing.active(in: c).first { $0.name == "Work" })
        try CategoryEditing.setColor(.plum, on: work)
        #expect(work.color == .plum)
        #expect(throws: SettingsError.notFound) { try CategoryEditing.setColor(.unknown, on: work) }
        let task = TaskItem(title: "T", dueDate: nil, effortMinutes: 10)
        c.insert(task); task.category = work
        CategoryEditing.archive(work)
        #expect(task.category === work)
    }
}
