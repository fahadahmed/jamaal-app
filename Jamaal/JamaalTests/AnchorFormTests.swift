//
//  AnchorFormTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The Anchor form's own rules: what each way of repeating does to the draft, adding and removing times, and the
/// words for them. Validating and writing is JamaalCore's `AnchorEditing`.
struct AnchorFormTests {
    private let today = CalendarDate(year: 2026, month: 10, day: 15)!

    private func form(_ source: AnchorSource = .schoolRun) -> AnchorForm {
        AnchorForm(draft: AnchorRuleDraft.preset(source, today: today), today: today)
    }

    @Test func eachWayOfRepeatingSetsTheDraftWithSensibleDefaults() {
        var f = form()
        f.chooseRepeat(.everyNDays)
        #expect(f.draft.repeats == .everyNDays(2))
        f.chooseRepeat(.everyNWeeks)
        #expect(f.draft.repeats == .everyNWeeks(2, [1, 2, 3, 4, 5]))                  // keeps the days it already had
        f.chooseRepeat(.afterLast)
        #expect(f.draft.repeats == .afterLast(minDays: 3, maxDays: 4))
        #expect(f.draft.placement == .flexible)
        f.chooseRepeat(.days)
        #expect(f.draft.repeats == .days([1, 2, 3, 4, 5]))
    }

    @Test func theCurrentWayIsReadBack() {
        var f = form()
        #expect(f.repeatKind == .days)
        f.chooseRepeat(.afterLast)
        #expect(f.repeatKind == .afterLast)
    }

    @Test func aPickedDayIsToggledAndTheLastOneStays() {
        var f = form(.binNight)                                                       // Wednesday only
        f.toggleDay(5)
        #expect(f.draft.repeats == .days([3, 5]))
        f.toggleDay(3); f.toggleDay(5)
        #expect(f.draft.repeats == .days([5]))                                        // never none
        var weeks = form()
        weeks.chooseRepeat(.everyNWeeks)
        weeks.toggleDay(1)
        #expect(weeks.draft.repeats == .everyNWeeks(2, [2, 3, 4, 5]))
    }

    @Test func theIntervalSteps() {
        var f = form()
        f.chooseRepeat(.everyNDays)
        f.stepInterval(by: 1); #expect(f.draft.repeats == .everyNDays(3))
        f.stepInterval(by: -10); #expect(f.draft.repeats == .everyNDays(1))
        f.chooseRepeat(.everyNWeeks)
        f.stepInterval(by: 20); #expect(f.draft.repeats == .everyNWeeks(8, [1, 2, 3, 4, 5]))
    }

    @Test func theLongestAfterLastIsNeverShorterThanTheShortest() {
        var f = form(.plantWatering)
        f.stepMinDays(by: 3)
        #expect(f.draft.repeats == .afterLast(minDays: 6, maxDays: 6))                // the maximum follows the minimum up
        f.stepMaxDays(by: -5)
        #expect(f.draft.repeats == .afterLast(minDays: 6, maxDays: 6))                // and stops at it
        f.stepMinDays(by: -10)
        #expect(f.draft.repeats == .afterLast(minDays: 1, maxDays: 6))
    }

    @Test func lastDoneIsTodayOrDueNow() {
        var f = form(.plantWatering)
        f.markDueNow()
        #expect(f.draft.startDate == today.addingDays(-3))
        f.markLastDoneToday()
        #expect(f.draft.startDate == today)
    }

    @Test func aSecondTimeIsNamedForTheSchoolRunAndTheLimitHolds() {
        var f = form()
        f.addSlot()
        #expect(f.draft.slots.count == 2 && f.draft.slots[1].label == "Pick-up" && f.draft.slots[1].startMinute == 15 * 60)
        for _ in 0..<10 { f.addSlot() }
        #expect(f.draft.slots.count == AnchorForm.maxSlots)
        #expect(!f.canAddSlot)
        #expect(Set(f.draft.slots.map(\.label)).count == AnchorForm.maxSlots)
    }

    @Test func aTimeCanBeRemovedUnlessItIsTheLastOne() {
        var f = form()
        f.addSlot()
        #expect(f.canRemoveSlot)
        f.removeSlot(at: 1)
        #expect(f.draft.slots.count == 1)
        #expect(!f.canRemoveSlot)
        f.removeSlot(at: 0)
        #expect(f.draft.slots.count == 1)
    }

    @Test func aTimeIsSummarisedByItsHours() {
        #expect(AnchorForm.summary(AnchorSlotDraft(label: "Drop-off", startMinute: 495, windowMinutes: 30)) == "08:15 · 30 min window")
        #expect(AnchorForm.summary(AnchorSlotDraft(label: "", allDay: true)) == "All day")
        #expect(AnchorForm.summary(AnchorSlotDraft(label: "Long", startMinute: 600, windowMinutes: 90)) == "10:00 · 1h 30m window")
    }

    @Test func theWindowSteps() {
        var s = AnchorSlotDraft(label: "X", windowMinutes: 30)
        AnchorForm.stepWindow(&s, by: 1); #expect(s.windowMinutes == 35)
        s.windowMinutes = 5
        AnchorForm.stepWindow(&s, by: -1); #expect(s.windowMinutes == 5)
        s.windowMinutes = 480
        AnchorForm.stepWindow(&s, by: 1); #expect(s.windowMinutes == 480)
    }

    @Test func theWaysOfRepeatingHaveTheirWords() {
        #expect(AnchorForm.repeatTitle(.days) == "On these days")
        #expect(AnchorForm.repeatTitle(.everyNDays) == "Every N days")
        #expect(AnchorForm.repeatTitle(.everyNWeeks) == "Every N weeks")
        #expect(AnchorForm.repeatTitle(.afterLast) == "After I last did it")
    }

    @Test func remindersAreOffByDefaultAndSaidPlainly() {
        var f = form()
        #expect(AnchorForm.reminderSummary(atStart: false, beforeEnd: nil) == "Off")
        #expect(AnchorForm.reminderSummary(atStart: true, beforeEnd: nil) == "At the start")
        #expect(AnchorForm.reminderSummary(atStart: false, beforeEnd: 10) == "10 min before it closes")
        #expect(AnchorForm.reminderSummary(atStart: true, beforeEnd: 10) == "At the start, and 10 min before it closes")
        f.draft.remindAtStart = true
        #expect(f.draft.remindAtStart)
    }
}
