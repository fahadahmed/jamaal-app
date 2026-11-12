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

/// Repeating tasks ask once whether a change is for this one or every one after (TK-07). "Every one after" is the plain edit, because
/// the live instance is the template the next one copies. "Only this one" leaves the series as it was: the next instance is made now
/// from the unchanged task, and this occurrence stops repeating, so there is still exactly one live instance of the series.
@MainActor
struct RepeatScopeTests {
    @Test func onlyRepeatingTasksNeedTheQuestion() throws {
        let w = try TaskWorld()
        let weekly = w.task("Timesheet", due: 15); weekly.repeatKind = "weekly"
        let plain = w.task("Call", due: 15)
        #expect(TaskEditing.needsScope(weekly))
        #expect(!TaskEditing.needsScope(plain))
    }

    @Test func onlyThisOneMakesTheNextInstanceFromTheUnchangedTaskAndDetachesThisOne() throws {
        let w = try TaskWorld()
        let t = w.task("Timesheet", due: 15, minutes: 30)           // Thu 15 Oct; weekly on Thursdays
        t.repeatKind = "weekly"; t.repeatWeekdays = "4"; t.seriesID = UUID()
        let series = t.seriesID

        let next = try #require(TaskActions.splitOffThisOccurrence(t, today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context))
        #expect(t.repeatMode == .off)
        #expect(t.seriesID == nil)
        #expect(next.effortMinutes == 30, "the next one keeps the old value, so the change is only for this one")
        #expect(next.seriesID == series)
        #expect(next.dueDate == w.d(22).storedDate)
        TaskEditing.setEffort(t, minutes: 45)
        let live = try w.context.fetch(FetchDescriptor<TaskItem>()).filter { $0.seriesID == series && !$0.isCompleted }
        #expect(live.map(\.id) == [next.id], "one live instance of the series")
        #expect(next.effortMinutes == 30)
    }

    @Test func completingTheDetachedOccurrenceMakesNoSecondNextInstance() throws {
        let w = try TaskWorld()
        let t = w.task("Timesheet", due: 15); t.repeatKind = "weekly"; t.repeatWeekdays = "4"; t.seriesID = UUID()
        TaskActions.splitOffThisOccurrence(t, today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context)
        TaskActions.complete(t, now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(try w.context.fetch(FetchDescriptor<TaskItem>()).count == 2)
    }

    @Test func aTaskThatDoesNotRepeatIsLeftAlone() throws {
        let w = try TaskWorld()
        let t = w.task("Call", due: 15)
        #expect(TaskActions.splitOffThisOccurrence(t, today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context) == nil)
    }

    @Test func undoingAVisitThatSplitTheSeriesPutsTheSeriesBack() throws {
        let w = try TaskWorld()
        let t = w.task("Timesheet", due: 15, minutes: 30); t.repeatKind = "weekly"; t.repeatWeekdays = "4"; t.seriesID = UUID()
        let series = t.seriesID
        let snapshot = TaskEditing.snapshot(t)
        let next = try #require(TaskActions.splitOffThisOccurrence(t, today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context))
        TaskEditing.setEffort(t, minutes: 45)

        TaskEditing.undoSplit(next, in: w.context)
        TaskEditing.restore(snapshot, to: t, categories: [])
        #expect(t.effortMinutes == 30)
        #expect(t.repeatMode == .weekly)
        #expect(t.seriesID == series)
        #expect(try w.context.fetch(FetchDescriptor<TaskItem>()).count == 1, "the extra instance is gone")
    }

    @Test func aTouchedNextInstanceIsNotRemovedByUndo() throws {
        let w = try TaskWorld()
        let t = w.task("Timesheet", due: 15); t.repeatKind = "weekly"; t.repeatWeekdays = "4"; t.seriesID = UUID()
        let next = try #require(TaskActions.splitOffThisOccurrence(t, today: w.d(15), now: w.at(15, 9), boundary: w.boundary, context: w.context))
        next.isCompleted = true; next.completedAt = w.at(22)
        TaskEditing.undoSplit(next, in: w.context)
        #expect(try w.context.fetch(FetchDescriptor<TaskItem>()).count == 2)
    }
}

/// The morning card names how many tasks were scheduled for today ahead of time (not carried here by the rollover, not added today).
@MainActor
struct ScheduledForTodayTests {
    @Test func countsLiveTasksDatedTodayBeforeTodayThatWereNotCarried() throws {
        let w = try TaskWorld()
        let scheduled = w.task("Dentist forms", due: 16, created: 5)
        let carried = w.task("Carried", due: 16, created: 5)
        let r = DeferralRecord(); r.day = w.d(15).storedDate; r.deferredTo = w.d(16).storedDate; w.context.insert(r); r.task = carried
        w.task("Added today", due: 16, created: 16)
        w.task("Tomorrow's", due: 17, created: 5)
        let done = w.task("Done", due: 16, created: 5); done.isCompleted = true; done.completedAt = w.at(16, 7)
        let found = try MorningCard.scheduledTasks(today: w.d(16), boundary: w.boundary, context: w.context)
        #expect(found.map(\.title) == ["Dentist forms"])
        _ = (scheduled, done)
    }
}
