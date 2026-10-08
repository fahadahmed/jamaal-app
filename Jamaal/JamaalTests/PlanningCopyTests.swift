//
//  PlanningCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// Night Planning's words. Each step opens with a short statement, never a verdict.
struct PlanningCopyTests {
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }       // Mon 5 Oct 2026

    @Test func theStepEyebrowCountsAndNamesTheStep() {
        #expect(PlanningCopy.eyebrow(position: 1, count: 5, step: .review) == "1 OF 5 · REVIEW")
        #expect(PlanningCopy.eyebrow(position: 2, count: 5, step: .carry) == "2 OF 5 · CARRY")
        #expect(PlanningCopy.eyebrow(position: 3, count: 5, step: .build) == "3 OF 5 · BUILD")
        #expect(PlanningCopy.eyebrow(position: 4, count: 5, step: .load) == "4 OF 5 · LOAD")
        #expect(PlanningCopy.eyebrow(position: 1, count: 3, step: .build) == "1 OF 3 · BUILD")
    }

    @Test func reviewOpensWithTheDayItReviews() {
        let h = PlanningCopy.reviewHeadline(date: d(5))
        #expect(h.plain == "How Monday")
        #expect(h.accent == "went.")
    }

    @Test func carryNamesHowManyDidntHappen() {
        #expect(PlanningCopy.carryHeadline(count: 1).plain == "One didn't")
        #expect(PlanningCopy.carryHeadline(count: 2).plain == "Two didn't")
        #expect(PlanningCopy.carryHeadline(count: 12).plain == "12 didn't")
        #expect(PlanningCopy.carryHeadline(count: 2).accent == "happen.")
    }

    @Test func buildNamesTheDayAndHowMuchOfItIsFree() {
        let h = PlanningCopy.buildHeadline(date: d(6))
        #expect(h.plain == "Tuesday's")
        #expect(h.accent == "shape.")
        #expect(PlanningCopy.buildLede(dayStartMinute: 480, dayEndMinute: 1140, freeMinutes: 400) == "08:00 to 19:00. About 6h 40m of it is free.")
    }

    @Test func theLoadHeadlineFollowsTheState() {
        #expect(PlanningCopy.loadHeadline(.light).plain == "Plenty of")
        #expect(PlanningCopy.loadHeadline(.light).accent == "room.")
        #expect(PlanningCopy.loadHeadline(.balanced).accent == "right.")
        #expect(PlanningCopy.loadHeadline(.full).accent == "full.")
        #expect(PlanningCopy.loadHeadline(.overloaded).plain == "A little")
        #expect(PlanningCopy.loadHeadline(.overloaded).accent == "much.")
        #expect(PlanningCopy.loadHeadline(.exhausting).accent == "much.")
    }

    @Test func theLevelLineSaysWhatTheWeekdayUsuallyIsAndWhatFits() {
        #expect(PlanningCopy.levelLine(date: d(6), usual: .medium, freeMinutes: 400, suggested: .medium) == "Tuesdays are usually medium. With 6h 40m free, medium fits.")
        #expect(PlanningCopy.levelLine(date: d(6), usual: .medium, freeMinutes: 150, suggested: .low) == "Tuesdays are usually medium. With 2h 30m free, low would fit better.")
    }

    @Test func theOverflowIsNamedInTheDaysTerms() {
        #expect(PlanningCopy.overflow(minutes: 40, dayEndMinute: 1140) == "40 min past 19:00")
        #expect(PlanningCopy.overflow(minutes: 130, dayEndMinute: 1140) == "2h 10m past 19:00")
    }

    @Test func theMoveOfferNamesTheTaskAndTheDay() {
        #expect(PlanningCopy.moveOffer(title: "Groceries", target: d(7), today: d(5)) == "Groceries could wait until Wednesday. Want me to move it?")
        #expect(PlanningCopy.moveOffer(title: "Groceries", target: nil, today: d(5)) == "Groceries could wait. Want me to pick a day for it?")
        #expect(PlanningCopy.moveButton(target: d(7)) == "Move to Wed")
        #expect(PlanningCopy.moveButton(target: nil) == "Pick a day")
    }

    @Test func closeSaysWhatTomorrowIsAndPutsThePhoneDown() {
        #expect(PlanningCopy.closeLine(tasks: 3, minutes: 165, firstAnchor: "The school run at 08:15") == "Three tasks, 2h 45m. The school run at 08:15 is first. Put the phone down.")
        #expect(PlanningCopy.closeLine(tasks: 1, minutes: 30, firstAnchor: nil) == "One task, 30m. Put the phone down.")
        #expect(PlanningCopy.closeLine(tasks: 0, minutes: 0, firstAnchor: nil) == "Nothing planned, and that's fine. Put the phone down.")
        #expect(PlanningCopy.nightsPlanned(12) == "12 nights planned")
        #expect(PlanningCopy.nightsPlanned(1) == "1 night planned")
    }

    @Test func reviewRowsReadAsPlainCounts() {
        #expect(PlanningCopy.tasksRow(done: 3, left: 2) == "3 done · 2 left")
        #expect(PlanningCopy.timeRow(actualMinutes: 160, estimatedMinutes: 135) == "2h 40m · estimated 2h 15m")
        #expect(PlanningCopy.timeRow(actualMinutes: 0, estimatedMinutes: 0) == nil)
        #expect(PlanningCopy.habitsRow(done: 6, due: 7, partial: "Water 2 of 3") == "6 of 7 · Water 2 of 3")
        #expect(PlanningCopy.habitsRow(done: 2, due: 2, partial: nil) == "2 of 2")
        #expect(PlanningCopy.habitsRow(done: 0, due: 0, partial: nil) == nil)
    }

    @Test func aCarryItemReadsEffortAndHowOftenItSlipped() {
        #expect(PlanningCopy.carryMeta(effortMinutes: 15, deferrals: 1) == "15 min · slipped once")
        #expect(PlanningCopy.carryMeta(effortMinutes: 30, deferrals: 2) == "30 min · slipped twice")
        #expect(PlanningCopy.carryMeta(effortMinutes: nil, deferrals: 0) == "")
        #expect(PlanningCopy.carryMeta(effortMinutes: 30, deferrals: 4) == "30 min · slipped 4 times")
    }

    // MARK: The morning flow

    @Test func theMorningEyebrowSaysThisMorning() {
        #expect(PlanningCopy.eyebrow(position: 1, count: 3, step: .build, mode: .morning) == "THIS MORNING · 1 OF 3")
        #expect(PlanningCopy.eyebrow(position: 2, count: 3, step: .load, mode: .morning) == "THIS MORNING · 2 OF 3")
        #expect(PlanningCopy.eyebrow(position: 1, count: 5, step: .review, mode: .evening) == "1 OF 5 · REVIEW")
    }

    @Test func theMorningBuildTalksAboutToday() {
        let h = PlanningCopy.buildHeadline(date: d(6), mode: .morning)
        #expect(h.plain == "Today's" && h.accent == "shape.")
        #expect(PlanningCopy.buildHeadline(date: d(6), mode: .evening).plain == "Tuesday's")
        #expect(PlanningCopy.buildLede(dayStartMinute: 480, dayEndMinute: 1140, freeMinutes: 430, mode: .morning) == "Until 19:00. About 7h 10m free.")
        #expect(PlanningCopy.tasksLabel(date: d(6), mode: .morning) == "Tasks for today")
        #expect(PlanningCopy.tasksLabel(date: d(6), mode: .evening) == "Tasks for Tuesday")
    }

    @Test func theMorningCanBeLeftWithNotNow() {
        #expect(PlanningCopy.skipTitle(.morning) == "Not now")
        #expect(PlanningCopy.skipTitle(.evening) == "Skip tonight")
    }

    @Test func theMorningCloseSaysTodayIsSet() {
        #expect(PlanningCopy.closeHeadline(.morning) == "Today is set.")
        #expect(PlanningCopy.closeHeadline(.evening) == "Tomorrow is ready.")
        #expect(PlanningCopy.morningCloseLine(tasks: 2, minutes: 105, level: .medium, firstAnchor: "The school run") == "Two tasks, 1h 45m, at medium. The school run is first.")
        #expect(PlanningCopy.morningCloseLine(tasks: 1, minutes: 30, level: .low, firstAnchor: nil) == "One task, 30m, at low.")
        #expect(PlanningCopy.morningCloseLine(tasks: 0, minutes: 0, level: .medium, firstAnchor: nil) == "Nothing planned, and that's fine.")
        #expect(PlanningCopy.closeAction(.morning) == "Open Today")
        #expect(PlanningCopy.closeAction(.evening) == "Good night")
    }

    @Test func todayNamesItselfUnplannedWhileTheCardIsUp() {
        let h = TodayCopy.unplanned(date: d(6))
        #expect(h.first == "Tuesday,")
        #expect(h.second == "unplanned.")
        #expect(TodayCopy.morningCard == "No plan for today — two minutes to pick?")
    }

    // MARK: The wide canvas's step rail

    @Test func theRailNamesEachStepAndTheMorningFlowSaysTodayNotTomorrow() {
        #expect(PlanningCopy.railTitle(.review, mode: .evening) == "Review today")
        #expect(PlanningCopy.railTitle(.carry, mode: .evening) == "Carry forward")
        #expect(PlanningCopy.railTitle(.build, mode: .evening) == "Build tomorrow")
        #expect(PlanningCopy.railTitle(.load, mode: .evening) == "Check the load")
        #expect(PlanningCopy.railTitle(.close, mode: .evening) == "Close the day")
        #expect(PlanningCopy.railTitle(.build, mode: .morning) == "Build today")
        #expect(PlanningCopy.railTitle(.close, mode: .morning) == "Set the day")
    }

    @Test func theRailEyebrowNamesTheDayBeingPlanned() {
        #expect(PlanningCopy.railEyebrow(for: d(6), mode: .evening) == "PLANNING TUESDAY")
        #expect(PlanningCopy.railEyebrow(for: d(6), mode: .morning) == "THIS MORNING")
    }

    @Test func theCarryLineSaysWhatIsLeftThenWhatWasDecided() {
        #expect(PlanningCopy.carryRail(pending: 2, moved: 0, dropped: 0, settled: false) == "2 to settle")
        #expect(PlanningCopy.carryRail(pending: 0, moved: 2, dropped: 0, settled: false) == "All settled")
        #expect(PlanningCopy.carryRail(pending: 1, moved: 1, dropped: 0, settled: true) == "1 kept · 1 moved")
        #expect(PlanningCopy.carryRail(pending: 0, moved: 1, dropped: 2, settled: true) == "1 moved · 2 dropped")
        #expect(PlanningCopy.carryRail(pending: 3, moved: 0, dropped: 0, settled: true) == "3 kept")
        #expect(PlanningCopy.carryRail(pending: 0, moved: 0, dropped: 0, settled: true) == "Nothing to settle")
    }

    @Test func theBuildLineCountsTasksAndTime() {
        #expect(PlanningCopy.buildRail(tasks: 4, minutes: 210) == "4 tasks · 3h 30m")
        #expect(PlanningCopy.buildRail(tasks: 1, minutes: 45) == "1 task · 45m")
        #expect(PlanningCopy.buildRail(tasks: 2, minutes: 0) == "2 tasks")
        #expect(PlanningCopy.buildRail(tasks: 0, minutes: 0) == "Nothing yet")
    }

    // MARK: The wide Build step

    @Test func aCommitmentInTheWideListDropsItsRulesName() {
        #expect(PlanningCopy.wideCommitmentTitle("School run · Drop-off") == "Drop-off")
        #expect(PlanningCopy.wideCommitmentTitle("Salah · Dhuhr") == "Dhuhr")
        #expect(PlanningCopy.wideCommitmentTitle("Site visit") == "Site visit")
    }

    @Test func theCommitmentsRunDownTwoColumnsInTimeOrder() {
        let (left, right) = PlanningCopy.columns(["a", "b", "c", "d", "e", "f"])
        #expect(left == ["a", "b", "c"] && right == ["d", "e", "f"])
        let odd = PlanningCopy.columns(["a", "b", "c", "d", "e"])
        #expect(odd.left == ["a", "b", "c"] && odd.right == ["d", "e"])
        let one = PlanningCopy.columns(["a"])
        #expect(one.left == ["a"] && one.right.isEmpty)
        let none = PlanningCopy.columns([String]())
        #expect(none.left.isEmpty && none.right.isEmpty)
    }

    @Test func theLongestGapIsNamedByWhatItSitsBetween() {
        #expect(PlanningCopy.longestGapLine(minutes: 105, after: "Dhuhr", before: "the pick-up") == "Longest gap: 1h 45m, between Dhuhr and the pick-up.")
        #expect(PlanningCopy.longestGapLine(minutes: 70, after: "Asr", before: nil) == "Longest gap: 1h 10m, after Asr.")
        #expect(PlanningCopy.longestGapLine(minutes: 65, after: nil, before: "Dhuhr") == "Longest gap: 1h 5m, before Dhuhr.")
        #expect(PlanningCopy.longestGapLine(minutes: 640, after: nil, before: nil) == nil)
    }
}
