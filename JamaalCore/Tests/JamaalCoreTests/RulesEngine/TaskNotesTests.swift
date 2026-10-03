import Foundation
import Testing
@testable import JamaalCore

/// A task's note is lightweight markdown; its checklist lines are tappable (task detail, focus screen).
struct TaskNotesTests {

    private let note = """
    - [ ] Ask about the **referral letter**
    - [x] Find the appointment number
    Some words in between
    - [ ] Are *Thursday mornings* still open?
    """

    @Test func checklistLinesBecomeCheckboxItemsAndOtherLinesStayText() {
        let items = TaskNotes.items(note)
        #expect(items.count == 4)
        #expect(items[0] == TaskNoteItem(line: 0, kind: .checkbox(isDone: false), text: "Ask about the **referral letter**"))
        #expect(items[1] == TaskNoteItem(line: 1, kind: .checkbox(isDone: true), text: "Find the appointment number"))
        #expect(items[2] == TaskNoteItem(line: 2, kind: .text, text: "Some words in between"))
        #expect(items[3].kind == .checkbox(isDone: false))
    }

    @Test func starsAndCapitalXAreChecklistSyntaxToo() {
        let items = TaskNotes.items("* [ ] one\n- [X] two\n+ [x] three")
        #expect(items.map(\.kind) == [.checkbox(isDone: false), .checkbox(isDone: true), .checkbox(isDone: true)])
        #expect(items.map(\.text) == ["one", "two", "three"])
    }

    @Test func aBoxWithoutTextOrSpaceIsNotAChecklistLine() {
        let items = TaskNotes.items("-[ ] no space\n- [] empty brackets\n[ ] no bullet")
        #expect(items.allSatisfy { $0.kind == .text })
    }

    @Test func blankLinesAreKeptOutOfTheItemsButNotLost() {
        let items = TaskNotes.items("- [ ] one\n\n- [ ] two")
        #expect(items.map(\.line) == [0, 2])
    }

    @Test func nilAndEmptyNotesHaveNoItems() {
        #expect(TaskNotes.items(nil).isEmpty)
        #expect(TaskNotes.items("").isEmpty)
    }

    @Test func togglingABoxChangesOnlyThatLine() throws {
        let toggled = try #require(TaskNotes.toggled(note, line: 0))
        #expect(toggled == """
        - [x] Ask about the **referral letter**
        - [x] Find the appointment number
        Some words in between
        - [ ] Are *Thursday mornings* still open?
        """)
        let back = try #require(TaskNotes.toggled(toggled, line: 0))
        #expect(back == note)
    }

    @Test func togglingADoneBoxUnticksItAndKeepsItsBullet() throws {
        #expect(TaskNotes.toggled("* [X] done", line: 0) == "* [ ] done")
    }

    @Test func togglingANonCheckboxOrAMissingLineChangesNothing() {
        #expect(TaskNotes.toggled(note, line: 2) == nil)
        #expect(TaskNotes.toggled(note, line: 99) == nil)
        #expect(TaskNotes.toggled(nil, line: 0) == nil)
    }

    @Test func theProgressCountsBoxesOnly() {
        #expect(TaskNotes.progress(note) == TaskNoteProgress(done: 1, total: 3))
        #expect(TaskNotes.progress("just words") == TaskNoteProgress(done: 0, total: 0))
    }
}

/// What Defer will do for a task, so the sheet can say it before the user chooses (docs/schema/task.md, "Deferral behaviour").
@MainActor
struct DeferPreviewTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }

    private func task(deferrals: Int, importance: Importance = .low, due: Int? = 5, repeating: Bool = false) -> TaskItem {
        let t = TaskItem(title: "Sort out the insurance renewal", dueDate: due.map { d($0).storedDate })
        t.deferralCount = deferrals
        t.importanceLevel = importance
        if repeating { t.repeatMode = .daily }
        return t
    }

    @Test func theFirstAndSecondDeferralsAreInstantToTomorrow() {
        for count in [0, 1] {
            let p = TaskDeferral.preview(task(deferrals: count), from: d(5))
            #expect(!p.requiresPicker)
            #expect(p.ordinal == count + 1)
        }
    }

    @Test func fromTheThirdADatePickerOpens() {
        let p = TaskDeferral.preview(task(deferrals: 2), from: d(5))
        #expect(p.requiresPicker)
        #expect(p.ordinal == 3)
        #expect(TaskDeferral.preview(task(deferrals: 4), from: d(5)).ordinal == 5)
    }

    @Test func aHighTaskWillEaseOnTheThirdAndThenSomedayIsOpen() {
        let p = TaskDeferral.preview(task(deferrals: 2, importance: .high), from: d(5))
        #expect(p.willEase)
        #expect(p.easesFrom == .high)
        #expect(p.somedayAllowed)
    }

    @Test func aLowTaskHasNothingToEaseAndSomedayIsOpen() {
        let p = TaskDeferral.preview(task(deferrals: 2, importance: .low), from: d(5))
        #expect(!p.willEase)
        #expect(p.easesFrom == nil)
        #expect(p.somedayAllowed)
    }

    @Test func anImportantTaskThatWontEaseYetCannotGoToSomeday() {
        let p = TaskDeferral.preview(task(deferrals: 0, importance: .medium), from: d(5))
        #expect(!p.willEase)
        #expect(!p.somedayAllowed)
    }

    @Test func aRepeatingTaskNeverGoesToSomeday() {
        #expect(!TaskDeferral.preview(task(deferrals: 2, repeating: true), from: d(5)).somedayAllowed)
    }

    @Test func aTaskNotDueYetNeverOpensThePickerEvenAfterManyDeferrals() {
        let p = TaskDeferral.preview(task(deferrals: 2, due: 9), from: d(5))
        #expect(p.isReschedule)
        #expect(!p.requiresPicker)
        #expect(p.easesFrom == nil)
    }

    @Test func aTaskNotDueYetIsRescheduledNotDeferred() {
        let p = TaskDeferral.preview(task(deferrals: 0, due: 9), from: d(5))
        #expect(p.isReschedule)
        #expect(!p.requiresPicker)
        let due = TaskDeferral.preview(task(deferrals: 0, due: 5), from: d(5))
        #expect(!due.isReschedule)
    }

    @Test func aSecondDeferralOnTheSameDayRefinesAndKeepsThePicker() {
        // The third deferral already happened today: its record exists and the task now sits on a later day.
        let t = task(deferrals: 3, importance: .medium, due: 8)
        let record = DeferralRecord(); record.day = d(5).storedDate
        t.deferrals = [record]
        let p = TaskDeferral.preview(t, from: d(5))
        #expect(p.requiresPicker)                       // already the third or later: a refinement, with the picker
        #expect(p.ordinal == 3)                         // it refines that day's third, not a fourth
        #expect(!p.isReschedule)                        // a refinement, though the task is now dated later
        #expect(!p.willEase)                            // the easing happened with the original deferral
    }

    @Test func theRemovalSuggestionComesWithTheFifth() {
        #expect(!TaskDeferral.preview(task(deferrals: 3), from: d(5)).suggestsRemoval)     // this would be the 4th
        #expect(TaskDeferral.preview(task(deferrals: 4), from: d(5)).suggestsRemoval)      // this would be the 5th
    }
}
