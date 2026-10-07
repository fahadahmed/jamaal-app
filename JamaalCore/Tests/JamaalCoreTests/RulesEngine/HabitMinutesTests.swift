import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Minutes added by hand (HB-09). Thu 15 Oct 2026, UTC; the habit exists from the 1st.
@MainActor
struct HabitMinutesTests {

    private func timed(_ w: TaskWorld, target: Int = 15) -> HabitTimeWindow {
        let habit = Habit(title: "Qur'an"); habit.habitKind = .timed; habit.createdAt = w.at(1, 0); w.context.insert(habit)
        let window = HabitTimeWindow(); window.target = target; w.context.insert(window); window.habit = habit
        return window
    }

    private func amount(_ w: TaskWorld, _ window: HabitTimeWindow, day: Int = 15) -> Int? {
        (window.entries ?? []).first { $0.date == w.d(day).storedDate }?.amount
    }

    @Test func minutesAddToTodaysEntryAsAManualSession() throws {
        let w = try TaskWorld()
        let window = timed(w)
        let session = try HabitMinutes.add(10, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        #expect(session.outcomeKind == .manual && session.actualSeconds == 600 && session.habitWindow === window)
        #expect(amount(w, window) == 10)
        #expect(HabitMinutes.progress(of: window, on: w.d(15)) == (10, 15))
        _ = try HabitMinutes.add(5, to: window, on: w.d(15), now: w.at(15, 9, 5), boundary: w.boundary, context: w.context)
        #expect(amount(w, window) == 15)
        let entry = try #require((window.entries ?? []).first)
        #expect(entry.completedAt != nil)                                         // the target is met
    }

    @Test func aPastDayWithinFourteenDaysTakesTheMinutesOnThatDay() throws {
        let w = try TaskWorld()
        let window = timed(w)
        try HabitMinutes.add(20, to: window, on: w.d(12), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        #expect(amount(w, window, day: 12) == 20 && amount(w, window, day: 15) == nil)
        try HabitMinutes.add(5, to: window, on: w.d(2), now: w.at(15, 9), boundary: w.boundary, context: w.context)      // 13 days back
        #expect(amount(w, window, day: 2) == 5)
    }

    @Test func daysOutsideTheCorrectionWindowAreRefusedAndWriteNothing() throws {
        let w = try TaskWorld()
        let window = timed(w)
        #expect(throws: HabitMinutesError.dayNotOpenForCorrection) {
            try HabitMinutes.add(10, to: window, on: w.d(1), now: w.at(15, 9), boundary: w.boundary, context: w.context)      // 14 days back
        }
        #expect(throws: HabitMinutesError.dayNotOpenForCorrection) {
            try HabitMinutes.add(10, to: window, on: w.d(16), now: w.at(15, 9), boundary: w.boundary, context: w.context)     // tomorrow
        }
        window.habit?.createdAt = w.at(10, 0)
        #expect(throws: HabitMinutesError.dayNotOpenForCorrection) {
            try HabitMinutes.add(10, to: window, on: w.d(9), now: w.at(15, 9), boundary: w.boundary, context: w.context)      // before it existed
        }
        #expect((window.sessions ?? []).isEmpty && (window.entries ?? []).isEmpty)
    }

    @Test func aPausedDayIsNotOpenEither() throws {
        let w = try TaskWorld()
        let window = timed(w)
        try HabitPauses.pause(try #require(window.habit), from: w.d(10), until: w.d(12), reason: .travel)
        #expect(throws: HabitMinutesError.dayNotOpenForCorrection) {
            try HabitMinutes.add(10, to: window, on: w.d(11), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        }
    }

    @Test func onlyTimedHabitsTakeMinutes() throws {
        let w = try TaskWorld()
        let window = timed(w)
        window.habit?.habitKind = .counted
        #expect(throws: HabitMinutesError.notATimedHabit) {
            try HabitMinutes.add(10, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        }
        for kind in [HabitKind.binary, .avoid] {
            window.habit?.habitKind = kind
            #expect(throws: HabitMinutesError.notATimedHabit) {
                try HabitMinutes.add(10, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
            }
        }
        let loose = HabitTimeWindow(); w.context.insert(loose)
        #expect(throws: HabitMinutesError.notATimedHabit) {
            try HabitMinutes.add(10, to: loose, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        }
    }

    @Test func theAmountMustBeBetweenOneMinuteAndTwelveHours() throws {
        let w = try TaskWorld()
        let window = timed(w)
        for bad in [0, -5, 721, 10_000] {
            #expect(throws: HabitMinutesError.minutesOutOfRange) {
                try HabitMinutes.add(bad, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
            }
        }
        try HabitMinutes.add(1, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        try HabitMinutes.add(720, to: window, on: w.d(15), now: w.at(15, 9, 1), boundary: w.boundary, context: w.context)
        #expect(amount(w, window) == 721)
    }

    @Test func aMistakenEntryCanBeTakenBackAndTheTotalFollows() throws {
        let w = try TaskWorld()
        let window = timed(w)
        let first = try HabitMinutes.add(10, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        let second = try HabitMinutes.add(30, to: window, on: w.d(15), now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(HabitMinutes.manualSessions(of: window, on: w.d(15)).map(\.actualSeconds) == [1800, 600])          // newest first
        #expect(HabitMinutes.remove(second, now: w.at(15, 11), context: w.context))
        #expect(amount(w, window) == 10)
        let entry = try #require((window.entries ?? []).first)
        #expect(entry.completedAt == nil)                                            // 10 of 15: no longer met
        #expect(HabitMinutes.remove(first, now: w.at(15, 11), context: w.context))
        #expect(amount(w, window) == 0 && HabitMinutes.manualSessions(of: window, on: w.d(15)).isEmpty)
    }

    @Test func aTimedSessionIsNeverRemovedThisWay() throws {
        let w = try TaskWorld()
        let window = timed(w)
        let live = try FocusSessions.begin(habitWindow: window, now: w.at(15, 7, 0), boundary: w.boundary, context: w.context)
        try FocusSessions.settle(live, as: .logIt, now: w.at(15, 7, 12), boundary: w.boundary, context: w.context)
        #expect(!HabitMinutes.remove(live, now: w.at(15, 8), context: w.context))
        #expect(amount(w, window) == 12 && HabitMinutes.manualSessions(of: window, on: w.d(15)).isEmpty)
    }

    @Test func theTargetShownIsTheOneTheDayWasLoggedAgainstEvenIfItChangedLater() throws {
        let w = try TaskWorld()
        let window = timed(w, target: 15)
        try HabitMinutes.add(10, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        window.target = 30                                                           // edited afterwards: affects the future only
        #expect(HabitMinutes.progress(of: window, on: w.d(15)) == (10, 15))
        #expect(HabitMinutes.progress(of: window, on: w.d(14)) == (0, 30))
    }

    @Test func theSheetStepsInFiveMinutesAndStartsAtTen() {
        #expect(HabitMinutes.step == 5 && HabitMinutes.defaultMinutes == 10)
        #expect(HabitMinutes.range == 1...720)
    }

    @Test func theListIsPerDay() throws {
        let w = try TaskWorld()
        let window = timed(w)
        try HabitMinutes.add(10, to: window, on: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        try HabitMinutes.add(20, to: window, on: w.d(14), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        #expect(HabitMinutes.manualSessions(of: window, on: w.d(14)).count == 1 && HabitMinutes.manualSessions(of: window, on: w.d(15)).count == 1)
        #expect(HabitMinutes.progress(of: window, on: w.d(13)) == (0, 15))
    }
}
