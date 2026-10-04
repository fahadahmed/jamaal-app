import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Creating and editing a habit (docs/journeys/walkthroughs/05-habits.md, HB-03/04/05, gaps G-37 and G-42).
@MainActor
struct HabitEditingTests {

    private let utc = TimeZone(identifier: "UTC")!
    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }
    private func create(_ draft: HabitDraft, _ c: ModelContext) throws -> Habit { try HabitEditing.create(draft, in: c, now: Date(timeIntervalSince1970: 1_790_000_000)) }

    // MARK: Drafts

    @Test func eachKindStartsWithASensibleTarget() {
        #expect(HabitDraft(kind: .binary).windows.first?.target == 1)
        #expect(HabitDraft(kind: .counted).windows.first?.target == 3)
        #expect(HabitDraft(kind: .timed).windows.first?.target == 15)
        #expect(HabitDraft(kind: .avoid).windows.first?.target == 1)
    }

    @Test func aNewDraftIsOneAllDayWindowEveryDay() {
        let d = HabitDraft(kind: .binary)
        #expect(d.windows.count == 1)
        #expect(d.windows[0].startMinute == 0 && d.windows[0].endMinute == 1439)
        #expect(d.weekdays == Set(1...7))
        #expect(d.perWeek == 0)
        #expect(d.windows[0].reminderMinute == nil)
    }

    @Test func thePresetsFillTheDraftAsTheCatalogueSays() {
        let quran = HabitDraft.preset(.quran)
        #expect(quran.title == "Qur'an reading")
        #expect(quran.kind == .timed)
        #expect(quran.windows[0].target == 15 && quran.windows[0].effortMinutes == 15)
        #expect(quran.perWeek == 0)
        let dhikr = HabitDraft.preset(.dhikr)
        #expect(dhikr.kind == .counted && dhikr.windows[0].target == 33 && dhikr.windows[0].effortMinutes == nil)
        let exercise = HabitDraft.preset(.exercise)
        #expect(exercise.kind == .timed && exercise.windows[0].target == 30 && exercise.perWeek == 3)
        let running = HabitDraft.preset(.running)
        #expect(running.title == "Running" && running.perWeek == 3)
        #expect(quran.presetKey == "quran")
    }

    // MARK: Creating

    @Test func creatingWritesTheHabitItsWindowAndItsSchedule() throws {
        let c = try context()
        var d = HabitDraft(kind: .counted)
        d.title = "  Water  "
        d.windows[0].target = 8
        d.windows[0].reminderMinute = 15 * 60
        let habit = try create(d, c)
        #expect(habit.title == "Water")
        #expect(habit.habitKind == .counted)
        #expect(habit.frequencyKind == .daily)
        #expect(habit.scheduledWeekdays == Set(1...7))
        let window = try #require(habit.windows?.first)
        #expect(window.target == 8)
        #expect(window.reminderMinute == 15 * 60)
        #expect(try c.fetchCount(FetchDescriptor<HabitTimeWindow>()) == 1)
    }

    @Test func theFrequencyFollowsTheDays() throws {
        let c = try context()
        var weekdays = HabitDraft(kind: .binary); weekdays.title = "Walk"; weekdays.weekdays = [1, 2, 3, 4, 5]
        #expect(try create(weekdays, c).frequencyKind == .weekdays)
        var custom = HabitDraft(kind: .binary); custom.title = "Bins"; custom.weekdays = [2, 5]
        let bins = try create(custom, c)
        #expect(bins.frequencyKind == .custom)
        #expect(bins.scheduledDays == "2,5")
        var weekly = HabitDraft(kind: .timed); weekly.title = "Run"; weekly.perWeek = 3
        let run = try create(weekly, c)
        #expect(run.frequencyKind == .custom)
        #expect(run.targetPerWeek == 3)
    }

    @Test func aBlankTitleIsRefusedAndWritesNothing() throws {
        let c = try context()
        #expect(throws: HabitEditError.emptyTitle) { try create(HabitDraft(kind: .binary), c) }
        #expect(try c.fetchCount(FetchDescriptor<Habit>()) == 0)
    }

    @Test func theTargetMustMakeSenseForTheKind() throws {
        let c = try context()
        for kind in [HabitKind.counted, .timed] {
            var d = HabitDraft(kind: kind); d.title = "X"; d.windows[0].target = 0
            #expect(throws: HabitEditError.targetTooSmall) { try create(d, c) }
        }
        var avoid = HabitDraft(kind: .avoid); avoid.title = "No sugar"; avoid.windows[0].target = 0
        #expect(try create(avoid, c).windows?.first?.target == 0)                  // none allowed is a real choice
        var negative = HabitDraft(kind: .avoid); negative.title = "Y"; negative.windows[0].target = -1
        #expect(throws: HabitEditError.targetTooSmall) { try create(negative, c) }
    }

    @Test func aHabitNeedsSomeDays() throws {
        let c = try context()
        var d = HabitDraft(kind: .binary); d.title = "X"; d.weekdays = []
        #expect(throws: HabitEditError.noDays) { try create(d, c) }
        d.perWeek = 2                                                                // "twice a week" needs no fixed days
        #expect(try create(d, c).targetPerWeek == 2)
    }

    @Test func aWeeklyTargetIsOneToSeven() throws {
        let c = try context()
        var d = HabitDraft(kind: .binary); d.title = "X"; d.perWeek = 8
        #expect(throws: HabitEditError.badWeeklyTarget) { try create(d, c) }
    }

    @Test func severalTimesADayNeedLabelsAndNoMoreThanFour() throws {
        let c = try context()
        var d = HabitDraft(kind: .binary); d.title = "Medication"
        d.windows = [
            HabitWindowDraft(label: "Morning", startMinute: 6 * 60, endMinute: 11 * 60, target: 1, reminderMinute: 8 * 60),
            HabitWindowDraft(label: "", startMinute: 18 * 60, endMinute: 23 * 60, target: 1),
        ]
        #expect(throws: HabitEditError.windowNeedsALabel) { try create(d, c) }
        d.windows[1].label = "Evening"
        let habit = try create(d, c)
        #expect(habit.windows?.count == 2)
        var five = HabitDraft(kind: .binary); five.title = "Five"
        five.windows = (0..<5).map { HabitWindowDraft(label: "T\($0)", startMinute: $0 * 60, endMinute: $0 * 60 + 30, target: 1) }
        #expect(throws: HabitEditError.tooManyWindows) { try create(five, c) }
    }

    @Test func aWindowMustEndAfterItStarts() throws {
        let c = try context()
        var d = HabitDraft(kind: .binary); d.title = "X"
        d.windows[0].startMinute = 600; d.windows[0].endMinute = 600
        #expect(throws: HabitEditError.windowEndsBeforeItStarts) { try create(d, c) }
    }

    @Test func aHabitCanBeCreatedInAGroupWithANote() throws {
        let c = try context()
        let g = HabitGroup(); g.title = "Morning"; c.insert(g)
        var d = HabitDraft(kind: .binary); d.title = "Stretch"; d.group = g; d.notes = "  Five minutes  "
        let habit = try create(d, c)
        #expect(habit.group === g)
        #expect(habit.notes == "Five minutes")
        var plain = HabitDraft(kind: .binary); plain.title = "Plain"; plain.notes = "   "
        #expect(try create(plain, c).notes == nil)
    }

    @Test func aPresetKeyIsKept() throws {
        let c = try context()
        var d = HabitDraft.preset(.dhikr)
        d.title = "Dhikr"
        #expect(try create(d, c).presetKey == "dhikr")
    }

    // MARK: Editing

    private func existing(_ c: ModelContext) throws -> Habit {
        var d = HabitDraft(kind: .counted); d.title = "Water"; d.windows[0].target = 8
        return try create(d, c)
    }

    @Test func aDraftFromAHabitCarriesItsFieldsAndWindowIDs() throws {
        let c = try context()
        let habit = try existing(c)
        let d = HabitDraft(editing: habit)
        #expect(d.title == "Water" && d.kind == .counted)
        #expect(d.windows.first?.target == 8)
        #expect(d.windows.first?.id == habit.windows?.first?.id)
        #expect(d.weekdays == Set(1...7))
    }

    @Test func editingChangesTheFieldsButNeverTheKind() throws {
        let c = try context()
        let habit = try existing(c)
        var d = HabitDraft(editing: habit)
        d.title = "Water, glasses"
        d.weekdays = [1, 2, 3, 4, 5]
        d.kind = .timed                                                              // ignored: the kind is fixed
        try HabitEditing.update(habit, with: d, in: c)
        #expect(habit.title == "Water, glasses")
        #expect(habit.habitKind == .counted)
        #expect(habit.frequencyKind == .weekdays)
    }

    @Test func aChangedTargetEditsTheWindowAndLeavesPastEntriesAlone() throws {
        let c = try context()
        let habit = try existing(c)
        let window = try #require(habit.windows?.first)
        let past = HabitEntry(); past.target = 8; past.amount = 8; c.insert(past); past.window = window
        var d = HabitDraft(editing: habit)
        d.windows[0].target = 10
        try HabitEditing.update(habit, with: d, in: c)
        #expect(window.target == 10)
        #expect(past.target == 8)                                                    // the snapshot stands
    }

    @Test func aTimeOfDayCanBeAddedLaterAndKeepsTheOthersEntries() throws {
        let c = try context()
        let habit = try existing(c)
        let first = try #require(habit.windows?.first)
        let entry = HabitEntry(); entry.amount = 3; c.insert(entry); entry.window = first
        var d = HabitDraft(editing: habit)
        d.windows[0].label = "Morning"
        d.windows.append(HabitWindowDraft(label: "Evening", startMinute: 18 * 60, endMinute: 23 * 60, target: 8, reminderMinute: 20 * 60))
        try HabitEditing.update(habit, with: d, in: c)
        #expect(habit.windows?.count == 2)
        #expect(first.label == "Morning")
        #expect(first.entries?.count == 1)
        #expect(habit.windows?.first { $0.label == "Evening" }?.reminderMinute == 20 * 60)
    }

    @Test func aTimeOfDayWithNoHistoryCanBeRemovedButOneWithHistoryCannot() throws {
        let c = try context()
        let habit = try existing(c)
        var d = HabitDraft(editing: habit)
        d.windows[0].label = "Morning"
        d.windows.append(HabitWindowDraft(label: "Evening", startMinute: 18 * 60, endMinute: 23 * 60, target: 8))
        try HabitEditing.update(habit, with: d, in: c)
        var removeEvening = HabitDraft(editing: habit)
        removeEvening.windows.removeAll { $0.label == "Evening" }
        try HabitEditing.update(habit, with: removeEvening, in: c)
        #expect(habit.windows?.count == 1)

        // Now give the remaining one some history and try to remove it by adding another and dropping it.
        let only = try #require(habit.windows?.first)
        let entry = HabitEntry(); entry.amount = 1; c.insert(entry); entry.window = only
        var replace = HabitDraft(editing: habit)
        replace.windows = [HabitWindowDraft(label: "Evening", startMinute: 18 * 60, endMinute: 23 * 60, target: 8)]
        #expect(throws: HabitEditError.windowHasHistory) { try HabitEditing.update(habit, with: replace, in: c) }
        #expect(habit.windows?.count == 1)
    }

    @Test func aFailedEditChangesNothing() throws {
        let c = try context()
        let habit = try existing(c)
        var d = HabitDraft(editing: habit)
        d.title = "Changed"
        d.weekdays = []
        #expect(throws: HabitEditError.noDays) { try HabitEditing.update(habit, with: d, in: c) }
        #expect(habit.title == "Water")
    }

    @Test func movingAHabitToAnotherGroupOrNone() throws {
        let c = try context()
        let g = HabitGroup(); g.title = "Morning"; c.insert(g)
        let habit = try existing(c)
        var d = HabitDraft(editing: habit); d.group = g
        try HabitEditing.update(habit, with: d, in: c)
        #expect(habit.group === g)
        d.group = nil
        try HabitEditing.update(habit, with: d, in: c)
        #expect(habit.group == nil)
    }

    // MARK: Groups

    @Test func aGroupIsMadeWithATrimmedTitleAndTheNextOrder() throws {
        let c = try context()
        let a = try HabitEditing.createGroup(named: "  Morning ", in: c)
        let b = try HabitEditing.createGroup(named: "Evening", in: c)
        #expect(a.title == "Morning")
        #expect(b.sortOrder == a.sortOrder + 1)
        #expect(throws: HabitEditError.emptyTitle) { try HabitEditing.createGroup(named: "   ", in: c) }
    }

    @Test func aWeeklyHabitIsScheduledOnAnyDayOfTheWeek() throws {
        let c = try context()
        var d = HabitDraft.preset(.exercise)
        d.weekdays = [2]
        let habit = try create(d, c)
        #expect(habit.scheduledDays == "1,2,3,4,5,6,7")
        #expect(habit.targetPerWeek == 3)
    }

    @Test func theHabitRemembersWhenItWasMadeAndHowLongOneOccurrenceTakes() throws {
        let c = try context()
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let habit = try HabitEditing.create(HabitDraft.preset(.quran), in: c, now: now)
        #expect(habit.createdAt == now)
        #expect(habit.windows?.first?.effortMinutes == 15)
    }

    @Test func editingChecksTheTargetAgainstTheHabitsOwnKindNotTheDraftsClaim() throws {
        let c = try context()
        let habit = try existing(c)                                                   // counted: a target of zero makes no sense
        var d = HabitDraft(editing: habit)
        d.kind = .avoid                                                               // would allow zero if it were believed
        d.windows[0].target = 0
        #expect(throws: HabitEditError.targetTooSmall) { try HabitEditing.update(habit, with: d, in: c) }
    }
}
