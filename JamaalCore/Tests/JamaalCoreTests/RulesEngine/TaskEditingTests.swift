import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Editing a task in place (docs/journeys/coming-up-and-day-review.md, "Task detail as the editor"): each field writes straight
/// to the task, a visit's changes are one undo group, and the rules (importance, repeat, Someday) still hold.
/// Today is Thu 15 Oct 2026 (UTC).
@MainActor
struct TaskEditingTests {
    private func world() throws -> TaskWorld { try TaskWorld() }

    // MARK: Setters

    @Test func theTitleIsTrimmedAndAnEmptyOneIsRefused() throws {
        let w = try world()
        let t = w.task("Call the clinic back", due: 15)
        #expect(TaskEditing.setTitle(t, "  Call the clinic  ") == true)
        #expect(t.title == "Call the clinic")
        #expect(TaskEditing.setTitle(t, "   ") == false, "an empty title reverts")
        #expect(t.title == "Call the clinic")
    }

    @Test func effortIsKeptInFifteenMinuteStepsBetweenFifteenAndEightHoursOrCleared() throws {
        let w = try world()
        let t = w.task("Draft", due: 15, minutes: 30)
        TaskEditing.setEffort(t, minutes: 90)
        #expect(t.effortMinutes == 90)
        TaskEditing.setEffort(t, minutes: 5)
        #expect(t.effortMinutes == 15, "never below fifteen")
        TaskEditing.setEffort(t, minutes: 9_999)
        #expect(t.effortMinutes == 480, "never above eight hours")
        TaskEditing.setEffort(t, minutes: nil)
        #expect(t.effortMinutes == nil, "no estimate is allowed")
    }

    @Test func makingATaskRepeatDatesItTodayIfItHadNoDate() throws {
        let w = try world()
        let t = w.task("Timesheet")
        TaskEditing.setRepeat(t, .weekly, today: w.d(15))
        #expect(t.repeatMode == .weekly)
        #expect(t.dueDate == w.d(15).storedDate)
        let dated = w.task("Rent", due: 20)
        TaskEditing.setRepeat(dated, .monthly, today: w.d(15))
        #expect(dated.dueDate == w.d(20).storedDate, "an existing date is kept")
        TaskEditing.setRepeat(dated, .off, today: w.d(15))
        #expect(dated.repeatMode == .off)
    }

    @Test func moveToTodayDatesTheTaskTodayWithoutCountingADeferral() throws {
        let w = try world()
        let t = w.task("Groceries", due: 18)
        try TaskEditing.moveToToday(t, today: w.d(15))
        #expect(t.dueDate == w.d(15).storedDate)
        #expect(t.deferralCount == 0)
        #expect((t.deferrals ?? []).isEmpty)
    }

    // MARK: A visit's undo group

    @Test func aVisitWithNoChangesHasNothingToUndo() throws {
        let w = try world()
        let t = w.task("Call", due: 15)
        let snap = TaskEditing.snapshot(t)
        #expect(TaskEditing.changes(from: snap, to: t).isEmpty)
    }

    @Test func changesNameWhatWasChangedInTheOrderTheRowsAreDrawn() throws {
        let w = try world()
        let t = w.task("Call the clinic back", due: 15, minutes: 15)
        let snap = TaskEditing.snapshot(t)
        TaskEditing.setEffort(t, minutes: 30)
        t.dueDate = w.d(17).storedDate
        _ = TaskEditing.setTitle(t, "Call the clinic")
        #expect(TaskEditing.changes(from: snap, to: t) == [.title("Call the clinic"), .effort(30), .due(w.d(17))])
    }

    @Test func undoRestoresEveryFieldChangedInTheVisit() throws {
        let w = try world()
        let cat = TaskCategory(); cat.name = "Work"; w.context.insert(cat)
        let t = w.task("Draft", due: 18, minutes: 60)
        t.category = cat
        let snap = TaskEditing.snapshot(t)

        _ = TaskEditing.setTitle(t, "Draft the review")
        TaskEditing.setEffort(t, minutes: 120)
        TaskRules.setImportance(t, to: .high, defaultDueDate: w.d(15))
        try TaskRules.setDueDate(t, to: w.d(16))
        t.category = nil
        TaskEditing.setRepeat(t, .weekly, today: w.d(15))

        TaskEditing.restore(snap, to: t, categories: [cat])
        #expect(t.title == "Draft")
        #expect(t.effortMinutes == 60)
        #expect(t.importanceLevel == .low)
        #expect(t.dueDate == w.d(18).storedDate)
        #expect(t.category?.id == cat.id)
        #expect(t.repeatMode == .off)
        #expect(TaskEditing.changes(from: snap, to: t).isEmpty)
    }

    @Test func undoAlsoBringsBackAClearedDateAndEstimate() throws {
        let w = try world()
        let t = w.task("Someday thing", minutes: 45)
        let snap = TaskEditing.snapshot(t)
        t.dueDate = w.d(16).storedDate
        TaskEditing.setEffort(t, minutes: nil)
        TaskEditing.restore(snap, to: t, categories: [])
        #expect(t.dueDate == nil)
        #expect(t.effortMinutes == 45)
    }
}
