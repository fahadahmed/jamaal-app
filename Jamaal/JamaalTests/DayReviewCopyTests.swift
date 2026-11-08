//
//  DayReviewCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct DayReviewCopyTests {
    private let monday = CalendarDate(year: 2026, month: 10, day: 12)!

    @Test func theEyebrowNamesTheDay() {
        #expect(DayReviewCopy.eyebrow(monday) == "Mon 12 Oct")
    }

    @Test func theHeroReadsTheDayPlainlyAndNeverScolds() {
        #expect(DayReviewCopy.hero(done: 2, planned: 3) == ("A steady day.", "Two of three done."))
        #expect(DayReviewCopy.hero(done: 3, planned: 3) == ("A full day.", "All three done."))
        #expect(DayReviewCopy.hero(done: 1, planned: 1) == ("A full day.", "The one task done."))
        #expect(DayReviewCopy.hero(done: 0, planned: 4) == ("A slow day.", "Nothing ticked off."))
        #expect(DayReviewCopy.hero(done: 0, planned: 0) == ("A quiet day.", "No tasks on the list."))
        #expect(DayReviewCopy.hero(done: 11, planned: 12) == ("A steady day.", "11 of 12 done."))
    }

    @Test func capacityUsedAndTheCloseTimeAreShortAndPlain() {
        #expect(DayReviewCopy.used(usedMinutes: 135, budgetMinutes: 180) == "2h 15m of 3h")
        #expect(DayReviewCopy.closed(time: "22:40") == "Closed 22:40")
    }

    @Test func anAnchorRuleReadsAsAttendedOfCountedAndASingleOneByItsOutcome() {
        #expect(DayReviewCopy.anchorGroup(attended: 4, counted: 5) == "4 of 5 attended")
        #expect(DayReviewCopy.anchorOutcome(.attended, time: "15:02") == "Attended 15:02")
        #expect(DayReviewCopy.anchorOutcome(.attended, time: nil) == "Attended")
        #expect(DayReviewCopy.anchorOutcome(.missed, time: nil) == "Missed")
        #expect(DayReviewCopy.anchorOutcome(.skipped, time: nil) == "Skipped")
        #expect(DayReviewCopy.anchorOutcome(.delegated, time: nil) == "Someone else did it")
        #expect(DayReviewCopy.anchorOutcome(.pending, time: nil) == "Not marked")
    }

    @Test func aHabitReadsAsItsAmountOrDone() {
        #expect(DayReviewCopy.habit(kind: .binary, state: .complete, amount: 1, target: 1) == "Done")
        #expect(DayReviewCopy.habit(kind: .binary, state: .missed, amount: 0, target: 1) == "Not done")
        #expect(DayReviewCopy.habit(kind: .counted, state: .partialHigh, amount: 2, target: 3) == "2 of 3")
        #expect(DayReviewCopy.habit(kind: .timed, state: .partialHigh, amount: 12, target: 20) == "12 of 20 min")
        #expect(DayReviewCopy.habit(kind: .avoid, state: .complete, amount: 0, target: 1) == "Held")
        #expect(DayReviewCopy.habit(kind: .avoid, state: .missed, amount: 2, target: 1) == "Slipped")
    }

    @Test func aTaskSaysWhatBecameOfIt() {
        let wed = CalendarDate(year: 2026, month: 10, day: 14)!
        #expect(DayReviewCopy.task(.done(at: Date(timeIntervalSince1970: 0)), doneTime: "09:12") == "Done 09:12")
        #expect(DayReviewCopy.task(.deferred(to: wed), doneTime: nil) == "Deferred to Wed 14 Oct")
        #expect(DayReviewCopy.task(.deferred(to: nil), doneTime: nil) == "Deferred to someday")
        #expect(DayReviewCopy.task(.carried(to: wed), doneTime: nil) == "Not done · carried to Wed 14 Oct")
        #expect(DayReviewCopy.task(.carried(to: nil), doneTime: nil) == "Not done · carried to someday")
        #expect(DayReviewCopy.task(.notDone, doneTime: nil) == "Not done")
    }

    @Test func theYesterdayRowSaysWhereItStands() {
        #expect(DayReviewCopy.yesterdayRow(.summary(done: 2, planned: 3)) == "Yesterday · 2 of 3 done")
        #expect(DayReviewCopy.yesterdayRow(.notPlanned) == "Yesterday · not planned")
        #expect(DayReviewCopy.yesterdayRow(.hidden) == nil)
    }

    @Test func theFooterIsHonestAboutWhatCanStillBeChanged() {
        #expect(DayReviewCopy.footer == "Past days are read-only. A missed task can be ticked for two days.")
        #expect(DayReviewCopy.empty.contains("Nothing"))
        #expect(![DayReviewCopy.footer, DayReviewCopy.empty].contains { $0.contains("!") })
    }
}
