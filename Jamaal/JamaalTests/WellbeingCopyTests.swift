//
//  WellbeingCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct WellbeingCopyTests {

    private func snapshot(
        tasks: Double? = 85, anchors: Double? = 90, habits: Double? = nil, heavy: Int = 2, active: Int = 14,
        done: Int = 41, toFinish: Int = 48, attended: Int = 63, decided: Int = 68
    ) -> WellbeingSnapshot {
        var parts: [WellbeingPart] = []
        if let tasks { parts.append(WellbeingPart(kind: .tasks, value: tasks, weight: 35)) }
        if let anchors { parts.append(WellbeingPart(kind: .anchors, value: anchors, weight: 25)) }
        if let habits { parts.append(WellbeingPart(kind: .habits, value: habits, weight: 20)) }
        return WellbeingSnapshot(
            state: .active(score: 78, trend: .aboutTheSame), activeDays: active, parts: parts, sparkline: [],
            completionPercent: tasks.map { Int($0) }, heavyDays: heavy, tasksDone: done, tasksToFinish: toFinish,
            anchorsAttended: attended, anchorsDecided: decided)
    }

    @Test func theTrendIsInWordsAgainstTwoWeeksEarlier() {
        #expect(WellbeingCopy.trend(.aboutTheSame) == "About the same as two weeks ago")
        #expect(WellbeingCopy.trend(.steadier) == "Steadier than two weeks ago")
        #expect(WellbeingCopy.trend(.heavier) == "Heavier than two weeks ago")
        #expect(WellbeingCopy.trend(nil) == nil)
    }

    @Test func theSteadyReadNamesTasksAnchorsAndHeavyDays() {
        #expect(WellbeingCopy.read(snapshot(), patterns: []) == "Most tasks got done, the Anchors held, and only two days ran heavy.")
        #expect(WellbeingCopy.read(snapshot(heavy: 0), patterns: []) == "Most tasks got done, the Anchors held, and no day ran heavy.")
        #expect(WellbeingCopy.read(snapshot(heavy: 1), patterns: []).hasSuffix("and one day ran heavy."))
        #expect(WellbeingCopy.read(snapshot(heavy: 6), patterns: []).hasSuffix("and six days ran heavy."))
    }

    @Test func theReadStaysPlainWhenThingsWereHarder() {
        #expect(WellbeingCopy.read(snapshot(tasks: 55, anchors: 60), patterns: []).hasPrefix("Some tasks got done, some Anchors slipped by"))
        #expect(WellbeingCopy.read(snapshot(tasks: 20), patterns: []).hasPrefix("Fewer tasks got done"))
    }

    @Test func withoutAnchorsOrTasksTheReadLeavesThemOut() {
        #expect(WellbeingCopy.read(snapshot(anchors: nil, decided: 0), patterns: []) == "Most tasks got done and only two days ran heavy.")
        #expect(WellbeingCopy.read(snapshot(tasks: nil, anchors: nil, heavy: 0, decided: 0), patterns: []) == "No day ran heavy.")
    }

    @Test func anActivePatternLeadsTheRead() {
        let heavy = [WellbeingPattern(kind: .heavyRun, subjectKey: "heavyRun")]
        #expect(WellbeingCopy.read(snapshot(), patterns: heavy) == "The last three days were each over their budget.")
        for kind in PatternKind.allCases {
            #expect(!WellbeingCopy.read(snapshot(), patterns: [WellbeingPattern(kind: kind, subjectKey: kind.rawValue)]).isEmpty)
        }
    }

    @Test func thereIsAWordForHowHabitsWentNotAFigure() {
        #expect(WellbeingCopy.habits(90) == "Most days" && WellbeingCopy.habits(75) == "Most days")
        #expect(WellbeingCopy.habits(60) == "Some days" && WellbeingCopy.habits(40) == "Some days")
        #expect(WellbeingCopy.habits(10) == "Fewer days")
    }

    @Test func theRowsAppearOnlyWhenThereIsSomethingBehindThem() {
        let all = WellbeingCopy.rows(snapshot(habits: 80))
        #expect(all.map(\.title) == ["Tasks done", "Anchors attended", "Habits", "Heavy days"])
        #expect(all.map(\.value) == ["41 of 48", "63 of 68", "Most days", "2 of 14"])
        let bare = WellbeingCopy.rows(snapshot(done: 0, toFinish: 0, attended: 0, decided: 0))
        #expect(bare.map(\.title) == ["Heavy days"])
    }

    @Test func gatheringCountsDaysAndNeverPassesSeven() {
        #expect(WellbeingCopy.gathering(activeDays: 4, needed: 7) == "4 of 7 days")
        #expect(WellbeingCopy.gathering(activeDays: 9, needed: 7) == "7 of 7 days")
        #expect(WellbeingCopy.strip(gathering: 4, needed: 7) == "Wellbeing · gathering data · 4 of 7")
        #expect(WellbeingCopy.willRead.map(\.title) == ["Tasks done", "Anchors attended", "Habits", "Load"])
    }

    @Test func eachPatternHasOneCardAndOneAction() {
        let habit = Habit(title: "Morning run")
        let cases = [
            (WellbeingPattern(kind: .heavyRun, subjectKey: "a"), "Make tomorrow a low day?", "Lower tomorrow"),
            (WellbeingPattern(kind: .weekendOverplan, subjectKey: "b", weekday: 6), "Saturdays have run over lately. Make Saturday a low day?", "Lighten Saturday"),
            (WellbeingPattern(kind: .weekendOverplan, subjectKey: "c", weekday: 7), "Make Sunday a low day?", "Lighten Sunday"),
            (WellbeingPattern(kind: .completionCollapse, subjectKey: "d"), "Lower your normal day", "Lower my normal day"),
            (WellbeingPattern(kind: .habitNeglect, subjectKey: "e", habit: habit), "Morning run has slipped a few days.", "Look at it"),
        ]
        for (pattern, text, action) in cases {
            #expect(WellbeingCopy.cardText(pattern).contains(text), "\(pattern.kind)")
            #expect(WellbeingCopy.cardAction(pattern) == action)
        }
    }

    @Test func aTakenActionLeavesAQuietLine() {
        #expect(WellbeingCopy.outcome(.capacityLowered(CalendarDate(year: 2026, month: 10, day: 16)!)) == "Tomorrow is a low day.")
        #expect(WellbeingCopy.outcome(.weekdayLowered(6)) == "Saturdays are low days now.")
        #expect(WellbeingCopy.outcome(.normalDayChanged(165)) == "Your normal day is now 2h 45m.")
        #expect(WellbeingCopy.outcome(.nothing) == nil)
    }
}
