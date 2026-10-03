import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Adding a task (docs/schema/task.md, journeys F03): what a draft needs, what creating it writes, and the
/// "Day is full · offer tomorrow" check that never blocks. Midnight rollover, UTC; Mon 5 Oct 2026 is a Monday.
@MainActor
struct TaskCreationTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func context() throws -> ModelContext {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        c.insert(UserSettings())
        return c
    }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int = 9) -> Date { boundary.instant(of: d(day), atMinute: hour * 60) }
    private func create(_ draft: TaskDraft, _ c: ModelContext, day: Int = 5) throws -> TaskItem {
        try TaskCreation.create(draft, in: c, now: at(day), timeZone: utc)
    }

    // MARK: Creating

    @Test func aNewDraftIsALowImportanceTaskWithThirtyMinutesAndNoDate() {
        let draft = TaskDraft(title: "Call Sam")
        #expect(draft.effortMinutes == 30)
        #expect(draft.importance == .low)
        #expect(draft.dueDate == nil)
        #expect(draft.repeatKind == .off)
    }

    @Test func aTitledDraftCreatesATaskWithItsFields() throws {
        let c = try context()
        var draft = TaskDraft(title: "  Submit the grant application  ")
        draft.effortMinutes = 210
        draft.importance = .high
        draft.dueDate = d(9)
        let task = try create(draft, c)
        #expect(task.title == "Submit the grant application")           // trimmed
        #expect(task.effortMinutes == 210)
        #expect(task.importanceLevel == .high)
        #expect(task.dueDate == d(9).storedDate)
        #expect(!task.isCompleted)
        #expect(try c.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }

    @Test func aBlankTitleIsRefusedAndCreatesNothing() throws {
        let c = try context()
        #expect(throws: TaskCreationError.emptyTitle) { try create(TaskDraft(title: "   "), c) }
        #expect(try c.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }

    @Test func aBacklogTaskNeedsNoDate() throws {
        let c = try context()
        let task = try create(TaskDraft(title: "Someday"), c)
        #expect(task.dueDate == nil)
    }

    @Test func mediumAndHighNeedADateAndAreNeverSomeday() throws {
        let c = try context()
        for level in [Importance.medium, .high] {
            var draft = TaskDraft(title: "Important")
            draft.importance = level
            #expect(throws: TaskCreationError.dateRequired) { try create(draft, c) }
        }
        #expect(try c.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }

    @Test func aRepeatingTaskNeedsADate() throws {
        let c = try context()
        var draft = TaskDraft(title: "Water the herbs")
        draft.repeatKind = .daily
        #expect(throws: TaskCreationError.dateRequired) { try create(draft, c) }
        draft.dueDate = d(5)
        #expect(try create(draft, c).repeatMode == .daily)
    }

    @Test func aWeeklyRepeatKeepsItsChosenWeekdaysAndAMonthlyOneItsDay() throws {
        let c = try context()
        var weekly = TaskDraft(title: "Bins"); weekly.dueDate = d(9); weekly.repeatKind = .weekly; weekly.repeatWeekdays = [5, 1]
        let w = try create(weekly, c)
        #expect(w.repeatMode == .weekly)
        #expect(w.repeatWeekdays == "1,5")                               // ISO weekdays, sorted
        var monthly = TaskDraft(title: "Rent"); monthly.dueDate = d(31); monthly.repeatKind = .monthly
        let m = try create(monthly, c)
        #expect(m.repeatMode == .monthly)
        #expect(m.repeatDayOfMonth == 0)                                  // the engine fills it on first completion
    }

    @Test func theCategoryIsAttached() throws {
        let c = try context()
        let work = TaskCategory(name: "Work"); c.insert(work)
        var draft = TaskDraft(title: "Reply"); draft.category = work
        let task = try create(draft, c)
        #expect(task.category === work)
    }

    // MARK: Day is full

    private func addTask(_ c: ModelContext, due: Int, minutes: Int, importance: Importance = .medium) {
        let t = TaskItem(title: "T\(due)-\(minutes)", dueDate: d(due).storedDate, effortMinutes: minutes)
        t.importanceLevel = importance
        c.insert(t)
    }
    private func check(_ c: ModelContext, minutes: Int?, on day: Int, now: Int = 5) throws -> DayFullCheck? {
        try TaskCreation.dayFullCheck(adding: minutes, on: d(day), in: c, now: at(now), timeZone: utc)
    }

    @Test func aDayWithRoomIsNotFull() throws {
        let c = try context()
        addTask(c, due: 5, minutes: 60)
        #expect(try check(c, minutes: 60, on: 5) == nil)                  // 120 of 180
        #expect(try check(c, minutes: 120, on: 5) == nil)                 // exactly 180 doesn't tip it over
    }

    @Test func aTaskThatTipsTheDayOverOffersTheNearestDayWithRoom() throws {
        let c = try context()
        addTask(c, due: 5, minutes: 130)                                  // Mon: 130 of 180
        addTask(c, due: 6, minutes: 170)                                  // Tue is nearly full
        let full = try #require(try check(c, minutes: 60, on: 5))
        #expect(full.plannedMinutes == 130)
        #expect(full.budgetMinutes == 180)
        #expect(full.suggestion == d(7))                                  // Tue has 170 + 60 > 180; Wed is empty
    }

    @Test func aTaskWithNoEstimateNeverTriggersIt() throws {
        let c = try context()
        addTask(c, due: 5, minutes: 200)
        #expect(try check(c, minutes: nil, on: 5) == nil)
        #expect(try check(c, minutes: 0, on: 5) == nil)
    }

    @Test func theBudgetIsThatDaysOwnLevel() throws {
        let c = try context()
        // Saturday 10 Oct defaults to low (2h = 120).
        addTask(c, due: 10, minutes: 90)
        let full = try #require(try check(c, minutes: 45, on: 10))
        #expect(full.budgetMinutes == 120)
    }

    @Test func todayCountsWhatIsAlreadyDoneToo() throws {
        let c = try context()
        let done = TaskItem(title: "Done", dueDate: d(5).storedDate, effortMinutes: 150)
        done.isCompleted = true; done.completedAt = at(5, 8)
        c.insert(done)
        let full = try #require(try check(c, minutes: 45, on: 5))        // 150 + 45 > 180
        #expect(full.plannedMinutes == 150)
    }

    @Test func noDayWithRoomMeansNoSuggestionButStillTheNote() throws {
        let c = try context()
        for day in 5...12 { addTask(c, due: day, minutes: 175) }
        let full = try #require(try check(c, minutes: 60, on: 5))
        #expect(full.suggestion == nil)
    }

    @Test func aDatelessTaskIsNeverChecked() throws {
        let c = try context()
        addTask(c, due: 5, minutes: 170)
        #expect(try TaskCreation.dayFullCheck(adding: 60, on: nil, in: c, now: at(5), timeZone: utc) == nil)
    }

    @Test func tomorrowIsOfferedWhenItHasRoom() throws {
        let c = try context()
        addTask(c, due: 5, minutes: 170)
        let full = try #require(try check(c, minutes: 30, on: 5))
        #expect(full.suggestion == d(6))
    }

    @Test func finishedOrDroppedTasksOnAnotherDayTakeNoRoom() throws {
        let c = try context()
        addTask(c, due: 5, minutes: 170)
        let done = TaskItem(title: "Done", dueDate: d(6).storedDate, effortMinutes: 170); done.isCompleted = true
        let dropped = TaskItem(title: "Dropped", dueDate: d(6).storedDate, effortMinutes: 170); dropped.droppedAt = at(5)
        c.insert(done); c.insert(dropped)
        let full = try #require(try check(c, minutes: 60, on: 5))
        #expect(full.suggestion == d(6))
    }
}
