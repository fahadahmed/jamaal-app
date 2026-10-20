import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// A privacy-safe look at what this device holds for timed habits, so two devices that disagree can be compared: short ids and
/// counts, never a title or a note.
@MainActor
struct SyncDiagnosticsTests {

    private func timedHabit(_ w: TaskWorld, title: String = "Secret name") -> (Habit, HabitTimeWindow) {
        let habit = Habit(); habit.title = title; habit.kind = "timed"
        let window = HabitTimeWindow(); window.target = 15
        w.context.insert(habit); w.context.insert(window)
        window.habit = habit
        return (habit, window)
    }

    private func entry(_ w: TaskWorld, _ window: HabitTimeWindow, day: Int, amount: Int) {
        let e = HabitEntry(); e.date = w.d(day).storedDate; e.amount = amount; e.target = 15
        w.context.insert(e); e.window = window
    }

    private func session(_ w: TaskWorld, _ window: HabitTimeWindow, day: Int, seconds: Int, outcome: SessionOutcome) {
        let s = WorkSession(); s.day = w.d(day).storedDate; s.actualSeconds = seconds; s.outcome = outcome.rawValue
        w.context.insert(s); s.habitWindow = window
    }

    @Test func aTimedHabitShowsItsEntriesAndSessionsForTheDay() throws {
        let w = try TaskWorld()
        let (_, window) = timedHabit(w)
        entry(w, window, day: 15, amount: 7)
        entry(w, window, day: 14, amount: 3)
        session(w, window, day: 15, seconds: 360, outcome: .finished)
        session(w, window, day: 15, seconds: 60, outcome: .manual)
        session(w, window, day: 15, seconds: 0, outcome: .running)
        let id = String(window.id.uuidString.prefix(4))
        let lines = SyncDiagnostics.timedHabitLines(in: w.context, today: w.d(15))
        #expect(lines.contains("Records: 1 habits, 1 windows, 2 entries, 3 sessions"))
        #expect(lines.contains("Timed window \(id): entries today [7], sessions today 3 (7 min ended, 1 running)"))
    }

    @Test func aWindowWithNothingTodayIsSaidPlainly() throws {
        let w = try TaskWorld()
        let (_, window) = timedHabit(w)
        let id = String(window.id.uuidString.prefix(4))
        #expect(SyncDiagnostics.timedHabitLines(in: w.context, today: w.d(15)).contains("Timed window \(id): entries today [], sessions today 0 (0 min ended, 0 running)"))
    }

    @Test func twoEntriesForTheSameDayBothShow() throws {
        let w = try TaskWorld()
        let (_, window) = timedHabit(w)
        entry(w, window, day: 15, amount: 7); entry(w, window, day: 15, amount: 0)
        let id = String(window.id.uuidString.prefix(4))
        #expect(SyncDiagnostics.timedHabitLines(in: w.context, today: w.d(15)).contains { $0.hasPrefix("Timed window \(id): entries today [0, 7]") })
    }

    @Test func nothingHere_NamesATitleOrANote() throws {
        let w = try TaskWorld()
        let (habit, _) = timedHabit(w, title: "Secret name"); habit.notes = "Secret note"
        let text = SyncDiagnostics.timedHabitLines(in: w.context, today: w.d(15)).joined(separator: "\n")
        #expect(!text.contains("Secret"))
    }

    @Test func aStoreWithNoTimedHabitsStillReportsItsCounts() throws {
        let w = try TaskWorld()
        #expect(SyncDiagnostics.timedHabitLines(in: w.context, today: w.d(15)) == ["Records: 0 habits, 0 windows, 0 entries, 0 sessions"])
    }

    @Test func theDetailsTextCarriesTheLinesWhenGiven() {
        let text = SyncStatusCopy.details(
            isOn: true, account: .available, activity: SyncActivity(), container: "c", device: "d", now: Date(timeIntervalSince1970: 0),
            extra: ["Records: 1 habits, 1 windows, 1 entries, 1 sessions"])
        #expect(text.hasSuffix("Records: 1 habits, 1 windows, 1 entries, 1 sessions"))
    }
}
