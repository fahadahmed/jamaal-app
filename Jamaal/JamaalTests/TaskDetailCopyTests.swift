//
//  TaskDetailCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The detail sheet's table and the defer sheet's words and choices.
struct TaskDetailCopyTests {
    private let today = CalendarDate(year: 2026, month: 10, day: 5)!          // a Monday
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }

    @Test func theTableReadsPlainly() {
        #expect(TaskDetailCopy.effort(15) == "15 min")
        #expect(TaskDetailCopy.effort(90) == "1h 30m")
        #expect(TaskDetailCopy.effort(60) == "1h")
        #expect(TaskDetailCopy.effort(nil) == "No estimate")
        #expect(TaskDetailCopy.matters(.low) == "Low")
        #expect(TaskDetailCopy.matters(.medium) == "Medium")
        #expect(TaskDetailCopy.matters(.high) == "High")
        #expect(TaskDetailCopy.due(nil, today: today) == "Someday")
        #expect(TaskDetailCopy.due(today, today: today) == "Today")
        #expect(TaskDetailCopy.due(d(6), today: today) == "Tomorrow")
        #expect(TaskDetailCopy.due(d(23), today: today) == "Fri 23 Oct")
        #expect(TaskDetailCopy.due(d(3), today: today) == "Overdue · Sat 3 Oct")
    }

    @Test func historyCountsDeferralsWithoutDrama() {
        let added = CalendarDate(year: 2026, month: 5, day: 9)!
        #expect(TaskDetailCopy.history(deferrals: 0, addedOn: added) == "Added 9 May")
        #expect(TaskDetailCopy.history(deferrals: 1, addedOn: added) == "Deferred once · added 9 May")
        #expect(TaskDetailCopy.history(deferrals: 2, addedOn: added) == "Deferred twice · added 9 May")
        #expect(TaskDetailCopy.history(deferrals: 4, addedOn: added) == "Deferred 4 times · added 9 May")
    }

    @Test func theOrdinalIsNamedUntilItIsJustANumber() {
        #expect(TaskDetailCopy.ordinal(1) == "First time")
        #expect(TaskDetailCopy.ordinal(3) == "Third time")
        #expect(TaskDetailCopy.ordinal(5) == "Fifth time")
        #expect(TaskDetailCopy.ordinal(7) == "7th time")
    }

    @Test func theCompanionLineNeverScolds() {
        let third = TaskDeferral.Preview(ordinal: 3, requiresPicker: true, isReschedule: false, willEase: false, easesFrom: nil, somedayAllowed: true, suggestsRemoval: false)
        #expect(TaskDetailCopy.deferLine(third) == "This one keeps slipping. Pick a day that actually works.")
        var fifth = third; fifth.ordinal = 5; fifth.suggestsRemoval = true
        #expect(TaskDetailCopy.deferLine(fifth) == "It's slipped 5 times. Letting it go is fine too.")
    }

    @Test func theEasingNoteSaysWhatChanged() {
        var p = TaskDeferral.Preview(ordinal: 3, requiresPicker: true, isReschedule: false, willEase: true, easesFrom: .high, somedayAllowed: true, suggestsRemoval: false)
        #expect(TaskDetailCopy.easeNote(p) == "It was high, so it's eased to low. Someday is open now.")
        p.easesFrom = .medium
        #expect(TaskDetailCopy.easeNote(p) == "It was medium, so it's eased to low. Someday is open now.")
        p.willEase = false; p.easesFrom = nil
        #expect(TaskDetailCopy.easeNote(p) == nil)
    }

    @Test func reasonChipsAreTheThreeFromTheSchema() {
        #expect(TaskDetailCopy.reasons.map(\.reason) == [.tooMuch, .notReady, .noLonger])
        #expect(TaskDetailCopy.reasons.map(\.title) == ["Too much on", "Not ready", "Not relevant"])
    }
}

struct DeferFormTests {
    private let today = CalendarDate(year: 2026, month: 10, day: 5)!          // Monday; the week starts Monday
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func preview(someday: Bool = true, ease: Bool = false) -> TaskDeferral.Preview {
        TaskDeferral.Preview(ordinal: 3, requiresPicker: true, isReschedule: false, willEase: ease, easesFrom: ease ? .high : nil, somedayAllowed: someday, suggestsRemoval: false)
    }
    private func form(someday: Bool = true) -> DeferForm { DeferForm(preview: preview(someday: someday), today: today, firstWeekdayISO: 1) }

    @Test func todayIsNeverOfferedAndTomorrowIsTheStartingChoice() {
        let f = form()
        #expect(!f.options.map(\.kind).contains(.today))
        #expect(f.options.first?.kind == .tomorrow)
        #expect(f.target == d(6))
    }

    @Test func somedayIsOfferedOnlyWhenAllowed() {
        #expect(form(someday: true).options.map(\.kind).contains(.someday))
        #expect(!form(someday: false).options.map(\.kind).contains(.someday))
    }

    @Test func choosingMovesTheTarget() {
        var f = form()
        f.choose(d(12))
        #expect(f.target == d(12))
        f.chooseSomeday()
        #expect(f.target == nil)
        #expect(f.isSomeday)
    }

    @Test func somedayIsRefusedWhenNotAllowed() {
        var f = form(someday: false)
        f.chooseSomeday()
        #expect(f.target == d(6))
    }

    @Test func aPickedDateMustBeALaterDay() {
        var f = form()
        f.choose(today)
        #expect(f.target == d(6))                                             // refused: stays
        f.choose(d(3))
        #expect(f.target == d(6))
    }

    @Test func theButtonSaysWhereItMoves() {
        var f = form()
        #expect(f.moveTitle == "Move to tomorrow")
        f.choose(d(9)); #expect(f.moveTitle == "Move to Friday")
        f.choose(d(19)); #expect(f.moveTitle == "Move to 19 Oct")
        f.chooseSomeday(); #expect(f.moveTitle == "Move to Someday")
    }

    @Test func aReasonIsOptionalAndCanBeClearedByTappingAgain() {
        var f = form()
        #expect(f.reason == .unspecified)
        f.toggleReason(.tooMuch)
        #expect(f.reason == .tooMuch)
        f.toggleReason(.notReady)
        #expect(f.reason == .notReady)
        f.toggleReason(.notReady)
        #expect(f.reason == .unspecified)
    }
}
