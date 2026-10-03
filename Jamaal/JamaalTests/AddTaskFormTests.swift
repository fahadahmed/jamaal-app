//
//  AddTaskFormTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The add sheet's own rules: what the chips offer, what choosing one does to the rest, and what the button says.
struct AddTaskFormTests {
    // Mon 5 Oct 2026.
    private let today = CalendarDate(year: 2026, month: 10, day: 5)!
    private func form() -> AddTaskForm { AddTaskForm(today: today, firstWeekdayISO: 1) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }

    @Test func aFreshFormIsEmptyLowAndThirtyMinutes() {
        let f = form()
        #expect(f.draft.title.isEmpty)
        #expect(f.draft.effortMinutes == 30)
        #expect(f.draft.importance == .low)
        #expect(f.draft.dueDate == nil)
        #expect(!f.canSubmit)
    }

    @Test func aTitleMakesItSubmittableButWhitespaceDoesNot() {
        var f = form()
        f.draft.title = "   "
        #expect(!f.canSubmit)
        f.draft.title = "Call Sam"
        #expect(f.canSubmit)
    }

    @Test func raisingImportanceDatesTheTaskTodayAndHidesSomeday() {
        var f = form()
        #expect(f.dueOptions.map(\.kind).contains(.someday))
        f.setImportance(.high)
        #expect(f.draft.dueDate == today)
        #expect(!f.dueOptions.map(\.kind).contains(.someday))
    }

    @Test func raisingImportanceKeepsADateAlreadyChosenAndLoweringNeverClearsOne() {
        var f = form()
        f.choose(d(9))
        f.setImportance(.medium)
        #expect(f.draft.dueDate == d(9))
        f.setImportance(.low)
        #expect(f.draft.dueDate == d(9))
    }

    @Test func choosingARepeatDatesTheTaskAndHidesSomeday() {
        var f = form()
        f.setRepeat(.weekly)
        #expect(f.draft.dueDate == today)
        #expect(!f.dueOptions.map(\.kind).contains(.someday))
        f.setRepeat(.off)
        #expect(f.draft.dueDate == today)                                   // the date stays
        #expect(f.dueOptions.map(\.kind).contains(.someday))
    }

    @Test func somedayIsRefusedWhileTheTaskNeedsADate() {
        var f = form()
        f.setImportance(.high)
        f.choose(nil)
        #expect(f.draft.dueDate == today)
        var g = form()
        g.choose(d(7)); g.choose(nil)
        #expect(g.draft.dueDate == nil)
    }

    @Test func effortStepsInFifteenMinutesBetweenFifteenAndEightHours() {
        var f = form()
        f.stepEffort(by: 1)
        #expect(f.draft.effortMinutes == 45)
        f.draft.effortMinutes = 15
        f.stepEffort(by: -1)
        #expect(f.draft.effortMinutes == 15)
        f.draft.effortMinutes = 480
        f.stepEffort(by: 1)
        #expect(f.draft.effortMinutes == 480)
        f.draft.effortMinutes = nil
        f.stepEffort(by: 1)
        #expect(f.draft.effortMinutes == 45)                                  // from the preselected 30
    }

    @Test func theChipsAreTheFourShortcutsAndACustomValueGetsItsOwn() {
        var f = form()
        #expect(f.effortChips == [15, 30, 60, 120])
        f.draft.effortMinutes = 210
        #expect(f.effortChips == [15, 30, 60, 120, 210])
        f.draft.effortMinutes = 60
        #expect(f.effortChips == [15, 30, 60, 120])
    }

    @Test func effortChipsAreNamedAsDesignDrawsThem() {
        #expect(AddTaskForm.effortTitle(15) == "15m")
        #expect(AddTaskForm.effortTitle(60) == "1h")
        #expect(AddTaskForm.effortTitle(120) == "2h+")
        #expect(AddTaskForm.effortTitle(210) == "3h 30m")
        #expect(AddTaskForm.effortTitle(90) == "1h 30m")
    }

    @Test func theButtonSaysWhatItWillDo() {
        var f = form()
        #expect(f.buttonTitle == "Add to someday")
        f.choose(today)
        #expect(f.buttonTitle == "Add for today")
        f.choose(d(6))
        #expect(f.buttonTitle == "Add for tomorrow")
        f.choose(d(9))
        #expect(f.buttonTitle == "Add for Friday")
        f.choose(d(19))
        #expect(f.buttonTitle == "Add for 19 Oct")
    }

    @Test func aPickedDateReadsAsADayAndDate() {
        #expect(AddTaskForm.dateTitle(d(23)) == "Fri 23 Oct")
        #expect(AddTaskForm.dateTitle(d(5)) == "Mon 5 Oct")
    }

    @Test func theDayFullPanelNamesTheNumbersAndTheOffer() {
        let tomorrow = AddTaskForm.dayFullCopy(
            DayFullCheck(plannedMinutes: 130, budgetMinutes: 180, suggestion: d(6)), adding: 60, on: today, today: today)
        #expect(tomorrow.title == "Day is full — put it on tomorrow?")
        #expect(tomorrow.detail == "Today is at 3h 10m of 3h. Tomorrow has room.")
        let wednesday = AddTaskForm.dayFullCopy(
            DayFullCheck(plannedMinutes: 130, budgetMinutes: 180, suggestion: d(7)), adding: 60, on: today, today: today)
        #expect(wednesday.title == "Day is full — put it on Wednesday?")
        #expect(wednesday.detail == "Today is at 3h 10m of 3h. Wednesday has room.")
        let none = AddTaskForm.dayFullCopy(
            DayFullCheck(plannedMinutes: 130, budgetMinutes: 180, suggestion: nil), adding: 60, on: d(9), today: today)
        #expect(none.title == "Day is full")
        #expect(none.detail == "Friday is at 3h 10m of 3h.")
    }
}
