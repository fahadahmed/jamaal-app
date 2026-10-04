//
//  HabitsCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The Habits tab's words: a one-line status per habit, the detail's eyebrow, schedule and read. Plain numbers; a
/// pause is a pause, not a lapse.
struct HabitsCopyTests {
    private func d(_ day: Int, month: Int = 5) -> CalendarDate { CalendarDate(year: 2026, month: month, day: day)! }
    private typealias W = HabitsCopy.WindowStatus

    @Test func countedAndTimedReadAmountOfTargetToday() {
        #expect(HabitsCopy.status(kind: .counted, windows: [W(label: "", startMinute: 0, amount: 3, target: 8, isDone: false)], weekly: nil, pause: nil) == "Counted · 3 of 8 today")
        #expect(HabitsCopy.status(kind: .timed, windows: [W(label: "", startMinute: 0, amount: 0, target: 15, isDone: false)], weekly: nil, pause: nil) == "Timed · 0 of 15 min today")
    }

    @Test func aWeeklyHabitReadsItsWeek() {
        #expect(HabitsCopy.status(kind: .timed, windows: [W(label: "", startMinute: 0, amount: 0, target: 30, isDone: false)], weekly: WeeklyProgress(done: 2, target: 3), pause: nil) == "Timed · 2 of 3 this week")
        #expect(HabitsCopy.status(kind: .binary, windows: [W(label: "", startMinute: 0, amount: 0, target: 1, isDone: false)], weekly: WeeklyProgress(done: 3, target: 3), pause: nil) == "Done · 3 of 3 this week")
    }

    @Test func aBinaryHabitSaysWhetherItIsDone() {
        #expect(HabitsCopy.status(kind: .binary, windows: [W(label: "", startMinute: 0, amount: 1, target: 1, isDone: true)], weekly: nil, pause: nil) == "Done today")
        #expect(HabitsCopy.status(kind: .binary, windows: [W(label: "", startMinute: 0, amount: 0, target: 1, isDone: false)], weekly: nil, pause: nil) == "Not yet today")
    }

    @Test func anAvoidHabitNeverScolds() {
        func status(amount: Int, done: Bool) -> String {
            HabitsCopy.status(kind: .avoid, windows: [W(label: "", startMinute: 0, amount: amount, target: 1, isDone: done)], weekly: nil, pause: nil)
        }
        #expect(status(amount: 0, done: false) == "Avoid · none today")
        #expect(status(amount: 1, done: false) == "Avoid · 1 slip today")
        #expect(status(amount: 3, done: false) == "Avoid · 3 slips today")
        #expect(status(amount: 0, done: true) == "Avoid · held today")
    }

    @Test func severalTimesADayNamesWhatIsDoneAndWhatIsNext() {
        let windows = [
            W(label: "Morning", startMinute: 8 * 60, amount: 1, target: 1, isDone: true),
            W(label: "Evening", startMinute: 20 * 60, amount: 0, target: 1, isDone: false),
        ]
        #expect(HabitsCopy.status(kind: .binary, windows: windows, weekly: nil, pause: nil) == "Morning done · evening at 20:00")
        let allDone = windows.map { var w = $0; w.isDone = true; return w }
        #expect(HabitsCopy.status(kind: .binary, windows: allDone, weekly: nil, pause: nil) == "All done today")
    }

    @Test func aPauseSaysWhyAndWhenItResumes() {
        let w = [W(label: "", startMinute: 0, amount: 0, target: 1, isDone: false)]
        #expect(HabitsCopy.status(kind: .binary, windows: w, weekly: nil, pause: HabitsCopy.PauseStatus(reason: .travel, endsOn: d(18))) == "Paused · travel · resumes 19 May")
        #expect(HabitsCopy.status(kind: .binary, windows: w, weekly: nil, pause: HabitsCopy.PauseStatus(reason: .illness, endsOn: nil)) == "Paused · illness · until you resume")
        #expect(HabitsCopy.status(kind: .binary, windows: w, weekly: nil, pause: HabitsCopy.PauseStatus(reason: .cycle, endsOn: d(31))) == "Paused · cycle · resumes 1 Jun")
        #expect(HabitsCopy.status(kind: .binary, windows: w, weekly: nil, pause: HabitsCopy.PauseStatus(reason: .other, endsOn: nil)) == "Paused · until you resume")
    }

    @Test func theGroupCardReadsTodaysCount() {
        #expect(HabitsCopy.groupCount(done: 2, due: 3) == "2 of 3 today")
        #expect(HabitsCopy.groupCount(done: 0, due: 0) == "nothing due today")
    }

    @Test func theDetailEyebrowNamesTheKindAndTarget() {
        #expect(HabitsCopy.eyebrow(kind: .counted, target: 8, weekly: nil) == "COUNTED · 8 A DAY")
        #expect(HabitsCopy.eyebrow(kind: .timed, target: 15, weekly: nil) == "TIMED · 15 MIN")
        #expect(HabitsCopy.eyebrow(kind: .avoid, target: 1, weekly: nil) == "AVOID · UP TO 1")
        #expect(HabitsCopy.eyebrow(kind: .avoid, target: 0, weekly: nil) == "AVOID · NONE ALLOWED")
        #expect(HabitsCopy.eyebrow(kind: .binary, target: 1, weekly: nil) == "DID IT")
        #expect(HabitsCopy.eyebrow(kind: .timed, target: 30, weekly: 3) == "TIMED · 30 MIN · 3 A WEEK")
    }

    @Test func theScheduleReadsAsDaysOrAWeeklyTarget() {
        #expect(HabitsCopy.schedule(weekdays: [1, 2, 3, 4, 5, 6, 7], perWeek: 0) == "Every day")
        #expect(HabitsCopy.schedule(weekdays: [1, 3, 5], perWeek: 0) == "Mon, Wed, Fri")
        #expect(HabitsCopy.schedule(weekdays: [1, 2, 3, 4, 5], perWeek: 0) == "Weekdays")
        #expect(HabitsCopy.schedule(weekdays: [6, 7], perWeek: 0) == "Weekends")
        #expect(HabitsCopy.schedule(weekdays: [], perWeek: 3) == "3 a week")
        #expect(HabitsCopy.schedule(weekdays: [1], perWeek: 1) == "Once a week")
    }

    @Test func theReadStatesNumbersAndOffersLighterOnlyGently() {
        #expect(HabitsCopy.read(DensityRead(windowDays: 42), kind: .counted) == "Nothing to read yet. A week or so of days first.")
        var read = DensityRead(windowDays: 42)
        read.completed = 31; read.partial = 2; read.missed = 5
        #expect(HabitsCopy.read(read, kind: .counted) == "Reached the target on 31 of 38 days.")
        #expect(HabitsCopy.read(read, kind: .avoid) == "Held on 31 of 38 days. Days nothing was logged stay empty: they aren't counted either way.")
        var slipping = DensityRead(windowDays: 21)
        slipping.completed = 4; slipping.missed = 9
        #expect(HabitsCopy.read(slipping, kind: .binary) == "Done on 4 of 13 days. That may be more than this season allows: try a lighter schedule?")
    }

    @Test func archiveAndPauseWordsAreWhatTheyDo() {
        #expect(HabitsCopy.reasonTitle(.travel) == "Travel")
        #expect(HabitsCopy.reasonTitle(.illness) == "Illness")
        #expect(HabitsCopy.reasonTitle(.cycle) == "Cycle")
        #expect(HabitsCopy.reasonTitle(.other) == "Other")
        #expect(HabitsCopy.archived(count: 1) == "ARCHIVED · 1")
    }
}
