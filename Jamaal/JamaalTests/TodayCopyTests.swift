//
//  TodayCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The words and figures Today shows. Calm, plain, never scolding.
struct TodayCopyTests {

    @Test(arguments: [
        (0, "0m"), (5, "5m"), (45, "45m"), (60, "1h"), (135, "2h 15m"), (180, "3h"), (245, "4h 5m"),
    ])
    func durationsReadInHoursAndMinutes(minutes: Int, text: String) {
        #expect(TodayCopy.duration(minutes) == text)
    }

    @Test func theMeterReadsPlannedOfBudget() {
        #expect(TodayCopy.meter(plannedMinutes: 135, budgetMinutes: 180) == "2h 15m of 3h")
        #expect(TodayCopy.meter(plannedMinutes: 0, budgetMinutes: 120) == "0m of 2h")
    }

    @Test func everyLoadStateHasACalmWord() {
        #expect(TodayCopy.stateWord(.light) == "LIGHT")
        #expect(TodayCopy.stateWord(.balanced) == "BALANCED")
        #expect(TodayCopy.stateWord(.full) == "FULL")
        #expect(TodayCopy.stateWord(.overloaded) == "OVER")
        #expect(TodayCopy.stateWord(.exhausting) == "OVER")
    }

    @Test func onlyTheOverloadedStatesAreFlagged() {
        #expect(!TodayCopy.isOver(.full))
        #expect(TodayCopy.isOver(.overloaded))
        #expect(TodayCopy.isOver(.exhausting))
    }

    @Test(arguments: [
        (0, "A clear day", "to begin."), (1, "One thing,", "gently paced."), (2, "Two things,", "gently paced."),
        (4, "Four things,", "gently paced."), (10, "Ten things,", "gently paced."), (13, "13 things,", "gently paced."),
    ])
    func theHeadlineCountsWhatIsLeft(count: Int, first: String, second: String) {
        let headline = TodayCopy.headline(remaining: count)
        #expect(headline.first == first)
        #expect(headline.second == second)
    }

    @Test func sliderLevelsMapToTheirLabelsAndBack() {
        #expect(TodayCopy.levels == [.low, .medium, .high])
        #expect(TodayCopy.label(for: .low) == "LOW")
        #expect(TodayCopy.label(for: .medium) == "MEDIUM")
        #expect(TodayCopy.label(for: .high) == "HIGH")
        #expect(TodayCopy.level(forStep: 0) == .low)
        #expect(TodayCopy.level(forStep: 1) == .medium)
        #expect(TodayCopy.level(forStep: 2) == .high)
        #expect(TodayCopy.level(forStep: 7) == .high)                       // clamped
        #expect(TodayCopy.level(forStep: -1) == .low)
        #expect(TodayCopy.step(for: .high) == 2)
        #expect(TodayCopy.step(for: .unknown) == 1)                         // reads as medium
    }

    @Test func aTaskRowSubtitleJoinsWhatIsKnown() {
        #expect(TodayCopy.taskMeta(deferrals: 0, effortMinutes: 60) == ["60 min"])
        #expect(TodayCopy.taskMeta(deferrals: 2, effortMinutes: 15) == ["Slipped twice", "15 min"])
        #expect(TodayCopy.taskMeta(deferrals: 1, effortMinutes: nil) == ["Slipped once"])
        #expect(TodayCopy.taskMeta(deferrals: 4, effortMinutes: 30) == ["Slipped 4 times", "30 min"])
        #expect(TodayCopy.taskMeta(deferrals: 0, effortMinutes: nil).isEmpty)
        #expect(TodayCopy.taskMeta(deferrals: 0, effortMinutes: 90) == ["90 min"])
    }

    @Test func theHeaderNamesTheLogicalDay() {
        #expect(TodayCopy.headerLabel(CalendarDate(year: 2026, month: 5, day: 12)!) == "TUE 12 MAY")
        #expect(TodayCopy.headerLabel(CalendarDate(year: 2026, month: 10, day: 4)!) == "SUN 4 OCT")
        #expect(TodayCopy.headerLabel(CalendarDate(year: 2026, month: 1, day: 5)!) == "MON 5 JAN")
    }
}

/// The Anchor rows' words: window state, outcome and the group line.
struct AnchorCopyTests {
    private let style = TodayCopy.TimeStyle(timeZone: TimeZone(identifier: "UTC")!, locale: Locale(identifier: "en_GB"))
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC"),
                       year: 2026, month: 10, day: day, hour: hour, minute: minute).date!
    }
    private func detail(
        status: AttendanceStatus = .pending, state: AnchorWindowState, start: Date? = nil, end: Date? = nil,
        resolved: Date? = nil, minutes: Int? = nil, endsToday: Bool = true
    ) -> String {
        TodayCopy.anchorDetail(
            status: status, state: state, windowStart: start ?? at(15, 15), windowEnd: end ?? at(15, 15, 32),
            resolvedAt: resolved, effortMinutes: minutes, endsToday: endsToday, style: style
        )
    }

    @Test func clockTimesFollowTheStyle() {
        #expect(TodayCopy.time(at(15, 15), style: style) == "15:00")
        #expect(TodayCopy.time(at(15, 9, 5), style: style) == "9:05")
    }

    @Test func anUpcomingWindowSaysWhenItOpensAndHowLong() {
        #expect(detail(state: .upcoming, minutes: 30) == "Opens at 15:00 · 30 min")
        #expect(detail(state: .upcoming) == "Opens at 15:00")
    }

    @Test func anOpenWindowSaysWhenItEndsOrWhichDay() {
        #expect(detail(state: .open) == "Open until 15:32")
        #expect(detail(state: .closingSoon) == "Closing soon · until 15:32")
        // 15 Oct 2026 is a Thursday; the window's last moment is on the following Wednesday.
        #expect(detail(state: .open, end: at(21, 24), endsToday: false) == "Open until Wednesday")
    }

    @Test func outcomesAreStatedPlainly() {
        #expect(detail(status: .attended, state: .closed, resolved: at(15, 12, 52)) == "Attended 12:52")
        #expect(detail(status: .skipped, state: .open) == "Not today")
        #expect(detail(status: .delegated, state: .open) == "Someone else did it")
        #expect(detail(status: .missed, state: .closed) == "Window closed at 15:32")
    }

    @Test func theTrailingFigureIsATimeADayCountOrNothing() {
        #expect(TodayCopy.anchorTrailing(state: .upcoming, windowStart: at(15, 15), dayNumber: 1, totalDays: 1, style: style) == "15:00")
        #expect(TodayCopy.anchorTrailing(state: .open, windowStart: at(15, 15), dayNumber: 2, totalDays: 3, style: style) == "Day 2 of 3")
        #expect(TodayCopy.anchorTrailing(state: .upcoming, windowStart: at(15, 15), dayNumber: 2, totalDays: 3, style: style) == "Day 2 of 3")
        #expect(TodayCopy.anchorTrailing(state: .open, windowStart: at(15, 15), dayNumber: 1, totalDays: 1, style: style) == nil)
    }

    @Test func aGroupReadsCountThenTheNextWindow() {
        #expect(TodayCopy.groupCount(attended: 1, counting: 5) == "1/5")
        #expect(TodayCopy.groupDetail(nextTitle: "Dhuhr", nextState: .open, nextStart: at(15, 12), nextEnd: at(15, 15, 32), allDecided: false, style: style) == "Dhuhr · until 15:32")
        #expect(TodayCopy.groupDetail(nextTitle: "Asr", nextState: .upcoming, nextStart: at(15, 15, 40), nextEnd: at(15, 17, 58), allDecided: false, style: style) == "Asr · from 15:40")
        #expect(TodayCopy.groupDetail(nextTitle: nil, nextState: nil, nextStart: nil, nextEnd: nil, allDecided: true, style: style) == "All done for today")
    }

    @Test func actionTitlesAreWhatTheyDo() {
        #expect(TodayCopy.title(for: .attended) == "Attended")
        #expect(TodayCopy.title(for: .notToday) == "Not today")
        #expect(TodayCopy.title(for: .someoneElseDidIt) == "Someone else did it")
        #expect(TodayCopy.title(for: .markDoneAfterAll) == "Mark as done after all")
        #expect(TodayCopy.title(for: .undo) == "Undo")
    }
}
