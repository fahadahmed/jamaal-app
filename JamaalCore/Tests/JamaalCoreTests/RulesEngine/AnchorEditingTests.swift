import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Making and editing Anchor rules and one-offs (docs/schema/anchor.md, journeys 04 AN-03…08). Thu 15 Oct 2026, UTC.
@MainActor
struct AnchorEditingTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }
    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }
    private func create(_ draft: AnchorRuleDraft, _ c: ModelContext) throws -> AnchorRule {
        try AnchorEditing.create(draft, in: c, now: at(15, 9))
    }
    private func scheduled(_ rule: AnchorRule) throws -> ScheduledConfig {
        guard case .scheduled(let config) = rule.config else { throw AnchorEditError.notAScheduledRule }
        return config
    }

    // MARK: Presets

    @Test func theSchoolRunPresetIsWeekdaysWithADropOffAndFixed() {
        let p = AnchorRuleDraft.preset(.schoolRun, today: d(15))
        #expect(p.title == "School run")
        #expect(p.repeats == .days([1, 2, 3, 4, 5]))
        #expect(p.slots.count == 1 && p.slots[0].label == "Drop-off" && p.slots[0].startMinute == 8 * 60 + 15 && p.slots[0].windowMinutes == 30)
        #expect(p.effortMinutes == 30)
        #expect(p.placement == .fixed)
    }

    @Test func theBinNightPresetIsOneWeekdayInTheEveningAndFlexible() {
        let p = AnchorRuleDraft.preset(.binNight, today: d(15))
        #expect(p.repeats == .days([3]))
        #expect(p.slots[0].label == "Bin night" && p.slots[0].startMinute == 19 * 60 && p.slots[0].windowMinutes == 180)
        #expect(p.effortMinutes == 10)
        #expect(p.placement == .flexible)
    }

    @Test func thePlantPresetIsAfterLastAllDayAndFlexible() {
        let p = AnchorRuleDraft.preset(.plantWatering, today: d(15))
        #expect(p.repeats == .afterLast(minDays: 3, maxDays: 4))
        #expect(p.slots[0].allDay)
        #expect(p.placement == .flexible)
        #expect(p.startDate == d(15))                                             // last handled: today
        #expect(p.effortMinutes == 10)
    }

    @Test func aCustomRuleStartsWithNoDaysAndNoTimes() {
        let p = AnchorRuleDraft.preset(.custom, today: d(15))
        #expect(p.repeats == .days([]))
        #expect(p.slots.isEmpty)
        #expect(p.placement == .fixed)
    }

    @Test func dueNowSetsTheLastHandledDayBackByTheMinimum() {
        var p = AnchorRuleDraft.preset(.plantWatering, today: d(15))
        p.markDueNow(today: d(15))
        #expect(p.startDate == d(12))                                             // 3 days ago: the window opens today
    }

    // MARK: Creating

    @Test func creatingWritesTheRuleItsConfigAndItsDefaults() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        #expect(rule.title == "School run")
        #expect(rule.source == .schoolRun)
        #expect(rule.placementKind == .fixed)
        #expect(rule.effortMinutes == 30)
        #expect(rule.createdAt == at(15, 9))
        let config = try scheduled(rule)
        #expect(config.recurrence == .weekly(weekdays: [1, 2, 3, 4, 5]))
        #expect(config.slots.first?.label == "Drop-off" && config.slots.first?.start == "08:15" && config.slots.first?.windowMinutes == 30)
    }

    @Test func eachRepeatKindIsStoredAsItsRecurrence() throws {
        let c = try context()
        var every = AnchorRuleDraft.preset(.custom, today: d(15)); every.title = "Gym"
        every.slots = [AnchorSlotDraft(label: "Gym", startMinute: 6 * 60, windowMinutes: 60)]
        every.repeats = .everyNDays(3); every.startDate = d(15)
        #expect(try scheduled(try create(every, c)).recurrence == .everyNDays(n: 3, startDate: d(15)))
        every.repeats = .everyNWeeks(2, [2, 4])
        #expect(try scheduled(try create(every, c)).recurrence == .everyNWeeks(n: 2, weekdays: [2, 4], startDate: d(15)))
        every.repeats = .afterLast(minDays: 3, maxDays: 5)
        every.slots = [AnchorSlotDraft(label: "", allDay: true)]
        let after = try create(every, c)
        #expect(try scheduled(after).recurrence == .afterLast(minDays: 3, maxDays: 5, startDate: d(15)))
        #expect(after.placementKind == .flexible)                                  // an afterLast rule is always flexible
    }

    @Test func slotsGetStableUniqueIDsAndAllDayIsKept() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.schoolRun, today: d(15))
        p.slots.append(AnchorSlotDraft(label: "Pick-up", startMinute: 15 * 60, windowMinutes: 30))
        let config = try scheduled(try create(p, c))
        #expect(Set(config.slots.map(\.id)).count == 2)
        #expect(config.slots.map(\.start) == ["08:15", "15:00"])
        var plants = AnchorRuleDraft.preset(.plantWatering, today: d(15))
        plants.slots = [AnchorSlotDraft(label: "", allDay: true)]
        #expect(try scheduled(try create(plants, c)).slots.first?.allDay == true)
    }

    @Test func theEndDateAndRemindersAreKept() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.schoolRun, today: d(15))
        p.endDate = d(30); p.remindAtStart = true; p.remindBeforeEndMinutes = 10
        let config = try scheduled(try create(p, c))
        #expect(config.endDate == d(30))
        #expect(config.reminder == AnchorReminder(atStart: true, beforeEndMinutes: 10))
        var none = AnchorRuleDraft.preset(.schoolRun, today: d(15))
        #expect(try scheduled(try create(none, c)).reminder == nil)                // nothing nags by default
        none.remindBeforeEndMinutes = 5
        #expect(try scheduled(try create(none, c)).reminder == AnchorReminder(atStart: false, beforeEndMinutes: 5))
    }

    // MARK: Refusals

    @Test func aBlankTitleIsRefusedAndWritesNothing() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.schoolRun, today: d(15)); p.title = "  "
        #expect(throws: AnchorEditError.emptyTitle) { try create(p, c) }
        #expect(try c.fetchCount(FetchDescriptor<AnchorRule>()) == 0)
    }

    @Test func aRuleNeedsDaysAndATime() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.custom, today: d(15)); p.title = "Choir"
        #expect(throws: AnchorEditError.noDays) { try create(p, c) }
        p.repeats = .days([4])
        #expect(throws: AnchorEditError.noTime) { try create(p, c) }
        p.slots = [AnchorSlotDraft(label: "Choir", startMinute: 19 * 60, windowMinutes: 60)]
        #expect(try create(p, c).title == "Choir")
    }

    @Test func intervalsMustMakeSense() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.schoolRun, today: d(15))
        p.repeats = .everyNDays(0)
        #expect(throws: AnchorEditError.badInterval) { try create(p, c) }
        p.repeats = .everyNWeeks(0, [1])
        #expect(throws: AnchorEditError.badInterval) { try create(p, c) }
        p.repeats = .afterLast(minDays: 4, maxDays: 3)
        #expect(throws: AnchorEditError.badInterval) { try create(p, c) }
        p.repeats = .afterLast(minDays: 0, maxDays: 3)
        #expect(throws: AnchorEditError.badInterval) { try create(p, c) }
    }

    @Test func severalTimesNeedNamesAndAWindowOfAtLeastOneMinute() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.schoolRun, today: d(15))
        p.slots.append(AnchorSlotDraft(label: "", startMinute: 15 * 60, windowMinutes: 30))
        #expect(throws: AnchorEditError.slotNeedsALabel) { try create(p, c) }
        p.slots[1].label = "Pick-up"; p.slots[1].windowMinutes = 0
        #expect(throws: AnchorEditError.windowTooShort) { try create(p, c) }
    }

    @Test func theEndMustNotBeBeforeToday() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.schoolRun, today: d(15))
        p.endDate = d(10)
        #expect(throws: AnchorEditError.endsBeforeItStarts) { try AnchorEditing.create(p, in: c, now: at(15, 9)) }
    }

    // MARK: Editing

    @Test func aDraftFromARuleCarriesItsFieldsAndKeepsSlotIDs() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        let draft = try #require(AnchorRuleDraft(editing: rule))
        #expect(draft.title == "School run" && draft.source == .schoolRun)
        #expect(draft.repeats == .days([1, 2, 3, 4, 5]))
        #expect(draft.slots.first?.id == (try scheduled(rule)).slots.first?.id)
        #expect(draft.effortMinutes == 30)
    }

    @Test func aPrayerOrUnreadableRuleCannotBeEditedHere() throws {
        let c = try context()
        let prayer = AnchorRule(title: "Salah"); prayer.source = .prayerWindow; prayer.configData = #"{"version":1}"#
        c.insert(prayer)
        #expect(AnchorRuleDraft(editing: prayer) == nil)
        let broken = AnchorRule(title: "X"); broken.configData = "nonsense"
        c.insert(broken)
        #expect(AnchorRuleDraft(editing: broken) == nil)
    }

    @Test func editingChangesTheRuleButKeepsItsExceptionsAndSlotKeys() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        try AnchorEditing.addException(to: rule, from: d(20), to: d(24), reason: .holiday)
        let originalSlot = try scheduled(rule).slots[0].id
        var draft = try #require(AnchorRuleDraft(editing: rule))
        draft.title = "School run (Mon–Thu)"
        draft.repeats = .days([1, 2, 3, 4])
        draft.slots[0].startMinute = 8 * 60 + 30
        try AnchorEditing.update(rule, with: draft, now: at(15, 9))
        let config = try scheduled(rule)
        #expect(rule.title == "School run (Mon–Thu)")
        #expect(config.recurrence == .weekly(weekdays: [1, 2, 3, 4]))
        #expect(config.slots[0].id == originalSlot)
        #expect(config.slots[0].start == "08:30")
        #expect(config.exceptions.count == 1)
    }

    @Test func aFailedEditChangesNothing() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        var draft = try #require(AnchorRuleDraft(editing: rule))
        draft.title = "Changed"; draft.repeats = .days([])
        #expect(throws: AnchorEditError.noDays) { try AnchorEditing.update(rule, with: draft, now: at(15, 9)) }
        #expect(rule.title == "School run")
    }

    // MARK: Exceptions

    @Test func anExceptionIsAddedWithItsReasonAndKeptInOrder() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        try AnchorEditing.addException(to: rule, from: d(28), to: d(30), reason: .travel)
        try AnchorEditing.addException(to: rule, from: d(20), to: d(24), reason: .holiday)
        let exceptions = try scheduled(rule).exceptions
        #expect(exceptions.map(\.from) == [d(20), d(28)])
        #expect(exceptions.first?.reasonKind == .holiday)
    }

    @Test func overlappingExceptionsMergeAndAnEndBeforeTheStartIsRefused() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        try AnchorEditing.addException(to: rule, from: d(20), to: d(24), reason: .holiday)
        try AnchorEditing.addException(to: rule, from: d(23), to: d(27), reason: .holiday)
        let merged = try scheduled(rule).exceptions
        #expect(merged.count == 1 && merged[0].from == d(20) && merged[0].to == d(27))
        try AnchorEditing.addException(to: rule, from: d(22), to: nil, reason: .other)       // open-ended swallows
        #expect(try scheduled(rule).exceptions.first?.to == nil)
        #expect(throws: AnchorEditError.endsBeforeItStarts) {
            try AnchorEditing.addException(to: rule, from: d(10), to: d(9), reason: .other)
        }
    }

    @Test func anExceptionCanBeRemoved() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        try AnchorEditing.addException(to: rule, from: d(20), to: d(24), reason: .holiday)
        try AnchorEditing.removeException(from: rule, at: 0)
        #expect(try scheduled(rule).exceptions.isEmpty)
        try AnchorEditing.removeException(from: rule, at: 5)                                   // nothing there: harmless
    }

    @Test func anUnreadableRuleTakesNoExceptions() throws {
        let c = try context()
        let broken = AnchorRule(title: "X"); broken.configData = "nonsense"; c.insert(broken)
        #expect(throws: AnchorEditError.notAScheduledRule) {
            try AnchorEditing.addException(to: broken, from: d(20), to: d(21), reason: .other)
        }
        #expect(throws: AnchorEditError.notAScheduledRule) { try AnchorEditing.removeException(from: broken, at: 0) }
    }

    // MARK: One-offs

    private func oneOff(title: String = "Dentist", day: Int = 16, from: Int = 15 * 60, to: Int = 16 * 60, _ c: ModelContext) throws -> Anchor {
        try AnchorEditing.createOneOff(
            title: title, on: d(day), startMinute: from, endMinute: to, effortMinutes: 45, remindAtStart: true, remindBeforeEndMinutes: nil,
            in: c, boundary: boundary, now: at(15, 9))
    }

    @Test func aOneOffIsAnAnchorWithNoRuleOnItsDay() throws {
        let c = try context()
        let a = try oneOff(c)
        #expect(a.rule == nil)
        #expect(a.title == "Dentist")
        #expect(a.occurrenceDate == d(16).storedDate)
        #expect(a.slotKey == "")
        #expect(a.windowStart == at(16, 15) && a.windowEnd == at(16, 16))
        #expect(a.effortMinutes == 45)
        #expect(a.status == .pending)
        #expect(a.remindBeforeStartMinutes == 0)
        #expect(a.remindBeforeEndMinutes == nil)
    }

    @Test func aOneOffNeedsATitleAnEndAfterTheStartAndAFutureEnd() throws {
        let c = try context()
        #expect(throws: AnchorEditError.emptyTitle) { try oneOff(title: " ", c) }
        #expect(throws: AnchorEditError.endsBeforeItStarts) { try oneOff(from: 16 * 60, to: 15 * 60, c) }
        #expect(throws: AnchorEditError.endsInThePast) { try oneOff(day: 15, from: 7 * 60, to: 8 * 60, c) }     // now is 09:00 on the 15th
        #expect(try c.fetchCount(FetchDescriptor<Anchor>()) == 0)
        #expect(try oneOff(day: 15, from: 8 * 60, to: 10 * 60, c).windowEnd == at(15, 10))                      // still running: fine
    }

    // MARK: Rules list

    @Test func theListShowsEachRuleWithItsStateAndNextAnchor() throws {
        let c = try context()
        let school = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        let bins = try create(AnchorRuleDraft.preset(.binNight, today: d(15)), c)
        let broken = AnchorRule(title: "Swimming"); broken.configData = "nonsense"; c.insert(broken)
        let overview = try AnchorsOverview.read(in: c, now: at(15, 9), boundary: boundary)
        #expect(overview.rows.count == 3)
        let schoolRow = try #require(overview.rows.first { $0.rule === school })
        #expect(schoolRow.state == .active)
        #expect(schoolRow.next?.occurrenceDate == d(16))                          // Thursday's 08:15 has passed: Friday
        #expect(overview.rows.first { $0.rule === bins }?.next?.occurrenceDate == d(21))      // Wednesday evening
        #expect(overview.rows.first { $0.rule === broken }?.state == .needsAttention(.unreadable))
    }

    @Test func aRuleInsideAnExceptionTodayIsPausedAndSaysUntilWhen() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        try AnchorEditing.addException(to: rule, from: d(14), to: d(18), reason: .holiday)
        let row = try #require(try AnchorsOverview.read(in: c, now: at(15, 9), boundary: boundary).rows.first)
        #expect(row.state == .paused(reason: .holiday, until: d(18)))
        #expect(row.next?.occurrenceDate == d(19))                                // Monday, once the break ends
    }

    @Test func archivedRulesAreListedApartAndAnEndedRuleHasNoNext() throws {
        let c = try context()
        let old = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        old.isArchived = true
        var p = AnchorRuleDraft.preset(.schoolRun, today: d(15)); p.title = "Ended"; p.endDate = d(15)
        _ = try create(p, c)
        let overview = try AnchorsOverview.read(in: c, now: at(15, 20), boundary: boundary)
        #expect(overview.archived.map(\.title) == ["School run"])
        #expect(overview.rows.count == 1)
        #expect(overview.rows.first?.next == nil)
    }

    @Test func thePlantsRuleOffersItsOpenWindow() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.plantWatering, today: d(15))
        p.markDueNow(today: d(15))
        let rule = try create(p, c)
        let row = try #require(try AnchorsOverview.read(in: c, now: at(15, 9), boundary: boundary).rows.first)
        #expect(row.next != nil)
        _ = rule
    }

    // MARK: Upcoming days

    @Test func upcomingDaysComeFromTheGeneratorsDryRun() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        let days = AnchorsOverview.upcoming(rule, from: d(15), days: 7, boundary: boundary)
        #expect(days.map(\.occurrenceDate) == [d(16), d(19), d(20), d(21)])               // Thursday's window ended before the rule existed
    }

    @Test func anAllDayTimeNeedsNoWindowLengthAndStoresNone() throws {
        let c = try context()
        var p = AnchorRuleDraft.preset(.plantWatering, today: d(15))
        p.slots = [AnchorSlotDraft(label: "", windowMinutes: 0, allDay: true)]
        #expect(try scheduled(try create(p, c)).slots.first?.allDay == true)             // a zero window is fine all day
        p.slots = [AnchorSlotDraft(label: "", windowMinutes: 45, allDay: true)]
        let slot = try #require(try scheduled(try create(p, c)).slots.first)
        #expect(slot.windowMinutes == 0)                                                  // and an all-day window stores none
    }

    @Test func aOneOffMustHaveSomeLength() throws {
        let c = try context()
        #expect(throws: AnchorEditError.endsBeforeItStarts) { try oneOff(from: 15 * 60, to: 15 * 60, c) }
    }

    @Test func aClosedExceptionInsideAnOpenEndedOneKeepsItOpen() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        try AnchorEditing.addException(to: rule, from: d(20), to: nil, reason: .travel)
        try AnchorEditing.addException(to: rule, from: d(22), to: d(25), reason: .holiday)
        let exceptions = try scheduled(rule).exceptions
        #expect(exceptions.count == 1)
        #expect(exceptions[0].to == nil)
    }

    @Test func aTimeAddedLaterGetsAKeyNoOtherTimeHas() throws {
        let c = try context()
        let rule = try create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), c)
        var draft = try #require(AnchorRuleDraft(editing: rule))
        draft.slots.append(AnchorSlotDraft(label: "Pick-up", startMinute: 15 * 60, windowMinutes: 30))
        try AnchorEditing.update(rule, with: draft, now: at(15, 9))
        let ids = try scheduled(rule).slots.map(\.id)
        #expect(ids.count == 2 && Set(ids).count == 2)
    }

    @Test func theNextAnchorSkipsAWindowThatHasAlreadyClosedToday() throws {
        let c = try context()
        let rule = try AnchorEditing.create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), in: c, now: at(15, 6))   // made before the drop-off
        let morning = try #require(try AnchorsOverview.read(in: c, now: at(15, 7), boundary: boundary).rows.first)
        #expect(morning.next?.occurrenceDate == d(15))                                                           // 08:15 still ahead
        let evening = try #require(try AnchorsOverview.read(in: c, now: at(15, 20), boundary: boundary).rows.first)
        #expect(evening.next?.occurrenceDate == d(16))                                                           // today's has closed
        _ = rule
    }

    @Test func rulesListInTheOrderTheyWereMade() throws {
        let c = try context()
        var b = AnchorRuleDraft.preset(.schoolRun, today: d(15)); b.title = "Zebra club"
        var a = AnchorRuleDraft.preset(.schoolRun, today: d(15)); a.title = "Art class"
        _ = try AnchorEditing.create(b, in: c, now: at(14, 9))
        _ = try AnchorEditing.create(a, in: c, now: at(15, 9))
        #expect(try AnchorsOverview.read(in: c, now: at(15, 10), boundary: boundary).rows.map(\.rule.title) == ["Zebra club", "Art class"])
    }
}
