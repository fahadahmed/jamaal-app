//
//  TaskEditCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct TaskEditCopyTests {
    private let thu = CalendarDate(year: 2026, month: 10, day: 15)!

    @Test func theUndoToastNamesTheTaskAndWhatChanged() {
        #expect(TaskEditCopy.undoText(title: "Call the clinic back", changes: [.effort(30)]) == "Call the clinic back · now 30 min")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.effort(nil)]) == "Draft · no estimate")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.matters(.high)]) == "Draft · now high")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.due(nil)]) == "Draft · now someday")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.due(thu)]) == "Draft · now Thu 15 Oct")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.category("Work")]) == "Draft · now Work")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.category(nil)]) == "Draft · no category")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.repeats(.weekly)]) == "Draft · now weekly")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.repeats(.off)]) == "Draft · no longer repeats")
        #expect(TaskEditCopy.undoText(title: "Draft it", changes: [.title("Draft it")]) == "Draft it · renamed")
    }

    @Test func severalChangesInOneVisitAreCountedNotListed() {
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.effort(30), .due(thu)]) == "Draft · 2 changes")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: []) == nil)
    }

    @Test func aFutureTaskSaysWhenItWillCount() {
        #expect(TaskEditCopy.futureNote(for: CalendarDate(year: 2026, month: 10, day: 16)!)
                == "This counts toward Friday's capacity once you plan that day. It stays off Today until then.")
    }

    @Test func thePickersAreCalmAndHonestAboutTheLimits() {
        #expect(TaskEditCopy.effortHelper.contains("splitting"))
        #expect(TaskEditCopy.savedLabel == "Saved")
        #expect(TaskEditCopy.moveToToday == "Move to today")
        #expect(TaskEditCopy.somedayNeedsADate == "Important and repeating tasks need a day. Lower its importance to park it.")
        #expect(![TaskEditCopy.effortHelper, TaskEditCopy.somedayNeedsADate].contains { $0.contains("!") })
    }

    @Test func effortOptionsAreTheSixInThePickerThenOther() {
        #expect(TaskEditCopy.effortOptions == [15, 30, 45, 60, 90, 120])
    }

    // MARK: Repeat scope (TK-07)

    @Test func theScopeSheetNamesTheRepeatRule() {
        #expect(TaskEditCopy.scopeEyebrow(kind: .weekly, weekday: "Monday", dayOfMonth: nil) == "Weekly on Monday")
        #expect(TaskEditCopy.scopeEyebrow(kind: .daily, weekday: nil, dayOfMonth: nil) == "Every day")
        #expect(TaskEditCopy.scopeEyebrow(kind: .monthly, weekday: nil, dayOfMonth: 1) == "Monthly on the 1st")
        #expect(TaskEditCopy.scopeEyebrow(kind: .monthly, weekday: nil, dayOfMonth: 22) == "Monthly on the 22nd")
        #expect(TaskEditCopy.scopeEyebrow(kind: .monthly, weekday: nil, dayOfMonth: 13) == "Monthly on the 13th")
        #expect(TaskEditCopy.scopeEyebrow(kind: .monthly, weekday: nil, dayOfMonth: 23) == "Monthly on the 23rd")
    }

    @Test func theScopeHeroAsksPlainly() {
        #expect(TaskEditCopy.scopeHero == ("Change just this one,", "or every one after?"))
    }

    @Test func theScopeSentenceNamesTheChange() {
        #expect(TaskEditCopy.scopeSentence(.effort(from: 30, to: 45)) == "Effort goes from 30 min to 45 min.")
        #expect(TaskEditCopy.scopeSentence(.effort(from: nil, to: 45)) == "Effort goes from no estimate to 45 min.")
        #expect(TaskEditCopy.scopeSentence(.effort(from: 45, to: nil)) == "Effort goes from 45 min to no estimate.")
        #expect(TaskEditCopy.scopeSentence(.matters(from: .low, to: .high)) == "Matters goes from low to high.")
        #expect(TaskEditCopy.scopeSentence(.category(from: "Work", to: "Family")) == "Category goes from Work to Family.")
        #expect(TaskEditCopy.scopeSentence(.category(from: nil, to: "Family")) == "Category goes from none to Family.")
        #expect(TaskEditCopy.scopeSentence(.title(to: "Submit timesheet")) == "The title becomes \u{201C}Submit timesheet\u{201D}.")
    }

    @Test func theScopeButtonsFollowTheRule() {
        #expect(TaskEditCopy.scopeLater(kind: .weekly, weekday: "Monday") == "This and later Mondays")
        #expect(TaskEditCopy.scopeOnly(kind: .weekly, weekday: "Monday") == "Only this Monday")
        #expect(TaskEditCopy.scopeLater(kind: .daily, weekday: nil) == "This and every day after")
        #expect(TaskEditCopy.scopeOnly(kind: .daily, weekday: nil) == "Only this day")
        #expect(TaskEditCopy.scopeLater(kind: .monthly, weekday: nil) == "This and later months")
        #expect(TaskEditCopy.scopeOnly(kind: .monthly, weekday: nil) == "Only this month")
        #expect(TaskEditCopy.scopeCancel == "Cancel")
    }

    // MARK: The morning card

    @Test func theMorningCardNamesHowManyTasksAreScheduledForToday() {
        #expect(TodayCopy.morningCard(scheduled: 0) == "No plan for today — two minutes to pick?")
        #expect(TodayCopy.morningCard(scheduled: 1) == "No plan for today. 1 task is scheduled for it, so two minutes to confirm?")
        #expect(TodayCopy.morningCard(scheduled: 3) == "No plan for today. 3 tasks are scheduled for it, so two minutes to confirm?")
    }
}
