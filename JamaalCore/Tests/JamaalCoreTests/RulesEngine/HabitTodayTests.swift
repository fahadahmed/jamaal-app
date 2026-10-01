import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Which habit windows Today shows, and the minutes they still take from the day.
@MainActor
struct HabitScheduleTests {

    @Test(arguments: [
        ("1,2,3,4,5,6,7", 1, true), ("1,2,3,4,5", 6, false), ("1,2,3,4,5", 5, true),
        ("1, 3 ,5", 3, true), ("1,x,3", 3, true), ("1,x,3", 2, false), ("", 1, false), ("8,0", 1, false),
    ])
    func scheduledDaysAreParsedTolerantly(days: String, weekday: Int, expected: Bool) throws {
        let w = try HabitWorld()
        let (habit, _) = w.habit(days: days)
        #expect(habit.scheduledWeekdays.contains(weekday) == expected)
    }

    @Test func aFixedDayHabitIsDueOnItsScheduledDaysOnly() throws {
        let w = try HabitWorld()
        let (habit, _) = w.habit(days: "1,3,5")
        #expect(HabitSchedule.isScheduled(habit, on: w.d(12)))     // Mon
        #expect(!HabitSchedule.isScheduled(habit, on: w.d(13)))    // Tue
    }

    @Test func aWeeklyTargetHabitIsScheduledEveryDay() throws {
        let w = try HabitWorld()
        let (habit, _) = w.habit(days: "", perWeek: 3)
        #expect(HabitSchedule.isScheduled(habit, on: w.d(13)))
    }

    @Test func archivedPausedAndNotYetCreatedHabitsAreNotActive() throws {
        let w = try HabitWorld()
        let (habit, _) = w.habit(createdOn: 12)
        let c = w.ctx(today: 15)
        #expect(!HabitSchedule.isActive(habit, on: w.d(11), context: c))
        #expect(HabitSchedule.isActive(habit, on: w.d(12), context: c))
        habit.pauses = [HabitPause(from: w.d(14), to: nil, reason: .other)]
        #expect(!HabitSchedule.isActive(habit, on: w.d(15), context: c))
        habit.pauses = []
        habit.isArchived = true
        #expect(!HabitSchedule.isActive(habit, on: w.d(15), context: c))
    }
}

@MainActor
struct HabitTodayTests {

    @Test func aDailyHabitIsDueAndNotDoneUntilLogged() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Read")
        var due = HabitToday.dueWindows(of: [habit], context: w.ctx(today: 15))
        #expect(due.map(\.window.id) == [window.id])
        #expect(due.first?.isDone == false)
        w.entry(window, day: 15, amount: 1)
        due = HabitToday.dueWindows(of: [habit], context: w.ctx(today: 15))
        #expect(due.first?.isDone == true)                          // still shown, as done
    }

    @Test func pausedArchivedAndUnscheduledHabitsAreHidden() throws {
        let w = try HabitWorld()
        let (paused, _) = w.habit("Paused"); paused.pauses = [HabitPause(from: w.d(14), to: nil, reason: .illness)]
        let (archived, _) = w.habit("Archived"); archived.isArchived = true
        let (offDay, _) = w.habit("Weekdays", days: "1,2,3,4,5")
        let sunday = 18
        #expect(HabitToday.dueWindows(of: [paused, archived], context: w.ctx(today: 15)).isEmpty)
        #expect(HabitToday.dueWindows(of: [offDay], context: w.ctx(today: sunday)).isEmpty)
    }

    @Test func aWeeklyTargetHabitShowsEveryDayUntilTheWeeksTargetIsMetThenAsDone() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Run", kind: .timed, target: 30, perWeek: 2, createdOn: 1)
        w.entry(window, day: 12, amount: 30)                         // Mon, week 12–18 Oct
        var due = HabitToday.dueWindows(of: [habit], context: w.ctx(today: 14))
        #expect(due.first?.isDone == false)                           // one of two so far: keep offering
        w.entry(window, day: 13, amount: 30)
        due = HabitToday.dueWindows(of: [habit], context: w.ctx(today: 14))
        #expect(due.first?.isDone == true)                            // met: done for the rest of the week
        due = HabitToday.dueWindows(of: [habit], context: w.ctx(today: 19))
        #expect(due.first?.isDone == false)                           // next week starts afresh
    }

    // MARK: Minutes still to do (what free time subtracts)

    @Test func aTimedWindowCountsItsRemainingMinutes() throws {
        let w = try HabitWorld()
        let (habit, window) = w.habit("Qur'an", kind: .timed, target: 20, effort: 20)
        w.entry(window, day: 15, amount: 12)
        let due = HabitToday.dueWindows(of: [habit], context: w.ctx(today: 15))
        #expect(HabitToday.remainingMinutes(due) == 8)
    }

    @Test func otherKindsCountTheirEffortUntilDone() throws {
        let w = try HabitWorld()
        let (stretch, stretchWindow) = w.habit("Stretch", effort: 10)
        let (read, readWindow) = w.habit("Read", effort: 25)
        let (water, _) = w.habit("Water", kind: .counted, target: 8)       // no duration
        w.entry(readWindow, day: 15, amount: 1)                              // done: stops counting
        _ = stretchWindow
        let due = HabitToday.dueWindows(of: [stretch, read, water], context: w.ctx(today: 15))
        #expect(HabitToday.remainingMinutes(due) == 10)
    }
}
