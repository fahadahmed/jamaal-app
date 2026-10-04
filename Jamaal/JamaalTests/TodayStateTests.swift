//
//  TodayStateTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// Which Today it is (a blank day, everything done, or the usual), and the words for the filter and the
/// carried-over row. A blank or finished day is stated, never scolded.
struct TodayStateTests {

    private func state(
        remaining: Int = 0, done: Int = 0, alsoToday: Int = 0, anchors: Int = 0, pendingAnchors: Int = 0, habits: Int = 0, unfinishedHabits: Int = 0
    ) -> TodayState {
        TodayState.of(TodayContent(
            remainingTasks: remaining, completedTasks: done, alsoToday: alsoToday,
            anchors: anchors, pendingAnchors: pendingAnchors, habits: habits, unfinishedHabits: unfinishedHabits))
    }

    @Test func nothingAtAllIsABlankDay() {
        #expect(state() == .blank)
    }

    @Test func anythingDueMakesItAnOrdinaryDay() {
        #expect(state(remaining: 1) == .normal)
        #expect(state(anchors: 1, pendingAnchors: 1) == .normal)
        #expect(state(habits: 2, unfinishedHabits: 1) == .normal)
        #expect(state(remaining: 0, done: 1, anchors: 1, pendingAnchors: 1) == .normal)
    }

    @Test func everythingDecidedIsAllDone() {
        #expect(state(done: 3) == .allDone)
        #expect(state(done: 1, anchors: 2, habits: 3) == .allDone)
        #expect(state(anchors: 1) == .allDone)                                 // only an attended Anchor
        #expect(state(habits: 2) == .allDone)
    }

    @Test func whatTheLevelHidesDoesNotKeepADayFromBeingDone() {
        #expect(state(done: 2, alsoToday: 3) == .allDone)
    }

    @Test func aDayWithOnlyHiddenTasksIsNotBlank() {
        #expect(state(alsoToday: 2) == .allDone)
    }

    @Test func theLinesAreCalm() {
        #expect(TodayCopy.blankDay == "Your day is blank.")
        #expect(TodayCopy.allDone == "Nothing left for today.")
        #expect(TodayCopy.nothingIn("Family") == "Nothing in Family today.")
    }

    @Test func theMeterSaysWhenItIsStillWholeDay() {
        #expect(TodayCopy.meter(plannedMinutes: 135, budgetMinutes: 180, wholeDay: false) == "2h 15m of 3h")
        #expect(TodayCopy.meter(plannedMinutes: 135, budgetMinutes: 180, wholeDay: true) == "2h 15m of 3h · whole day")
    }

    @Test func theCarriedOverRowNamesWhatWasKept() {
        let line = TodayCopy.pickUp(minutes: 42, title: "Draft the architecture review", closedAt: "midnight")
        #expect(line.before == "Last night's session closed at midnight. 42 min logged on ")
        #expect(line.title == "Draft the architecture review")
        #expect(line.after == ".")
    }

    @Test func theClosingTimeIsMidnightOrAClockTime() {
        #expect(TodayCopy.closeTime(rolloverMinute: 0) == "midnight")
        #expect(TodayCopy.closeTime(rolloverMinute: 180) == "03:00")
        #expect(TodayCopy.closeTime(rolloverMinute: 90) == "01:30")
    }

    @Test func aSessionOfUnderAMinuteIsStillNamedPlainly() {
        #expect(TodayCopy.pickUp(minutes: 0, title: "X", closedAt: "midnight").before == "Last night's session closed at midnight. Under a minute logged on ")
        #expect(TodayCopy.pickUp(minutes: 1, title: "X", closedAt: "midnight").before.contains("1 min logged"))
    }
}
