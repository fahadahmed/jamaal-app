//
//  TaskEditCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct TaskEditCopyTests {
    private let thu = CalendarDate(year: 2026, month: 10, day: 15)!

    @Test func theUndoToastNamesTheTaskAndWhatChanged() {
        #expect(TaskEditCopy.undoText(title: "Call the clinic back", changes: [.effort(30)]) == "Call the clinic back · now 30 min")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.effort(nil)]) == "Draft · no estimate")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.matters(.high)]) == "Draft · now high")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.due(nil)]) == "Draft · now someday")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.due(thu)]) == "Draft · now Thu 15 Oct")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.category("Work")]) == "Draft · now Work")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.category(nil)]) == "Draft · no category")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.repeats(.weekly)]) == "Draft · now weekly")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.repeats(.off)]) == "Draft · no longer repeats")
        #expect(TaskEditCopy.undoText(title: "Draft it", changes: [.title("Draft it")]) == "Draft it · renamed")
    }

    @Test func severalChangesInOneVisitAreCountedNotListed() {
        #expect(TaskEditCopy.undoText(title: "Draft", changes: [.effort(30), .due(thu)]) == "Draft · 2 changes")
        #expect(TaskEditCopy.undoText(title: "Draft", changes: []) == nil)
    }

    @Test func aFutureTaskSaysWhenItWillCount() {
        #expect(TaskEditCopy.futureNote(for: CalendarDate(year: 2026, month: 10, day: 16)!)
                == "This counts toward Friday's capacity once you plan that day. It stays off Today until then.")
    }

    @Test func thePickersAreCalmAndHonestAboutTheLimits() {
        #expect(TaskEditCopy.effortHelper.contains("splitting"))
        #expect(TaskEditCopy.savedLabel == "Saved")
        #expect(TaskEditCopy.moveToToday == "Move to today")
        #expect(TaskEditCopy.somedayNeedsADate == "Important and repeating tasks need a day. Lower its importance to park it.")
        #expect(![TaskEditCopy.effortHelper, TaskEditCopy.somedayNeedsADate].contains { $0.contains("!") })
    }

    @Test func effortOptionsAreTheSixInThePickerThenOther() {
        #expect(TaskEditCopy.effortOptions == [15, 30, 45, 60, 90, 120])
    }
}
