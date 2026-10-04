//
//  HabitFormTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The habit form's own rules: what each schedule choice does to the draft, adding and removing times of day, how
/// the target steps, and the words for a refusal. Creating and validating is JamaalCore's `HabitEditing`.
struct HabitFormTests {

    private func form(_ kind: HabitKind = .binary) -> HabitForm { HabitForm(draft: HabitDraft(kind: kind)) }

    // MARK: Schedule

    @Test func eachScheduleChoiceSetsTheDraft() {
        var f = form()
        f.setSchedule(.weekdays)
        #expect(f.draft.weekdays == [1, 2, 3, 4, 5] && f.draft.perWeek == 0)
        f.setSchedule(.days([1, 3]))
        #expect(f.draft.weekdays == [1, 3] && f.draft.perWeek == 0)
        f.setSchedule(.perWeek(3))
        #expect(f.draft.perWeek == 3)
        f.setSchedule(.everyDay)
        #expect(f.draft.weekdays == Set(1...7) && f.draft.perWeek == 0)
    }

    @Test func theChoiceIsReadBackFromTheDraft() {
        var f = form()
        #expect(f.schedule == .everyDay)
        f.draft.weekdays = [1, 2, 3, 4, 5]
        #expect(f.schedule == .weekdays)
        f.draft.weekdays = [2, 4]
        #expect(f.schedule == .days([2, 4]))
        f.draft.perWeek = 2
        #expect(f.schedule == .perWeek(2))
    }

    @Test func aPickedDayIsToggledAndTheLastOneStays() {
        var f = form()
        f.setSchedule(.days([1, 3]))
        f.toggleDay(5)
        #expect(f.draft.weekdays == [1, 3, 5])
        f.toggleDay(1); f.toggleDay(3)
        #expect(f.draft.weekdays == [5])
        f.toggleDay(5)
        #expect(f.draft.weekdays == [5])                                      // never leaves it with no days
    }

    @Test func theWeeklyStepperStaysBetweenOneAndSeven() {
        var f = form()
        f.setSchedule(.perWeek(3))
        f.stepPerWeek(by: 10); #expect(f.draft.perWeek == 7)
        f.stepPerWeek(by: -10); #expect(f.draft.perWeek == 1)
    }

    // MARK: Target

    @Test func theTargetStepsByTheKind() {
        var counted = form(.counted)
        counted.stepTarget(by: 1); #expect(counted.draft.windows[0].target == 4)
        counted.draft.windows[0].target = 1
        counted.stepTarget(by: -1); #expect(counted.draft.windows[0].target == 1)
        var timed = form(.timed)
        timed.stepTarget(by: 1); #expect(timed.draft.windows[0].target == 20)
        timed.draft.windows[0].target = 5
        timed.stepTarget(by: -1); #expect(timed.draft.windows[0].target == 5)
        var avoid = form(.avoid)
        avoid.stepTarget(by: -1); #expect(avoid.draft.windows[0].target == 0)
        avoid.stepTarget(by: -1); #expect(avoid.draft.windows[0].target == 0)
        var binary = form(.binary)
        binary.stepTarget(by: 1); #expect(binary.draft.windows[0].target == 1)
    }

    @Test func theTargetIsDescribedInTheKindsOwnWords() {
        #expect(HabitForm.targetTitle(kind: .counted, target: 8) == "8 times a day")
        #expect(HabitForm.targetTitle(kind: .timed, target: 15) == "15 minutes")
        #expect(HabitForm.targetTitle(kind: .avoid, target: 1) == "Up to 1 a day")
        #expect(HabitForm.targetTitle(kind: .avoid, target: 0) == "None allowed")
        #expect(HabitForm.targetTitle(kind: .binary, target: 1) == nil)
    }

    // MARK: Times of day

    @Test func addingASecondTimeNamesBothAndGivesThemSensibleHours() {
        var f = form()
        f.addWindow()
        #expect(f.draft.windows.count == 2)
        #expect(f.draft.windows[0].label == "Morning")
        #expect(f.draft.windows[0].startMinute == 6 * 60 && f.draft.windows[0].endMinute == 12 * 60)
        #expect(f.draft.windows[1].label == "Evening")
        #expect(f.draft.windows[1].startMinute == 18 * 60 && f.draft.windows[1].endMinute == 23 * 60)
        #expect(f.draft.windows[1].target == f.draft.windows[0].target)
    }

    @Test func aWindowAlreadyEditedIsNotRewrittenWhenAnotherIsAdded() {
        var f = form()
        f.draft.windows[0].label = "After lunch"; f.draft.windows[0].startMinute = 13 * 60; f.draft.windows[0].endMinute = 14 * 60
        f.addWindow()
        #expect(f.draft.windows[0].label == "After lunch")
        #expect(f.draft.windows[0].startMinute == 13 * 60)
    }

    @Test func atMostFourTimesAndTheNamesDontRepeat() {
        var f = form()
        for _ in 0..<6 { f.addWindow() }
        #expect(f.draft.windows.count == 4)
        #expect(Set(f.draft.windows.map(\.label)).count == 4)
        #expect(!f.canAddWindow)
    }

    @Test func aTimeOfDayCanBeRemovedUnlessItHasHistoryOrIsTheLast() {
        var f = form()
        f.addWindow()
        let history = Set([f.draft.windows[0].id ?? UUID()])
        #expect(f.canRemoveWindow(at: 1, withHistory: history))
        f.removeWindow(at: 1)
        #expect(f.draft.windows.count == 1)
        #expect(!f.canRemoveWindow(at: 0, withHistory: []))                   // the last one stays
        var g = form()
        g.addWindow()
        g.draft.windows[0].id = UUID()
        #expect(!g.canRemoveWindow(at: 0, withHistory: [g.draft.windows[0].id!]))
    }

    @Test func aWindowIsSummarisedByItsHoursAndReminder() {
        #expect(HabitForm.summary(HabitWindowDraft(label: "Morning", startMinute: 360, endMinute: 660, target: 1, reminderMinute: 480)) == "06:00–11:00 · remind 08:00")
        #expect(HabitForm.summary(HabitWindowDraft(label: "", target: 1)) == "All day")
        #expect(HabitForm.summary(HabitWindowDraft(label: "", target: 1, reminderMinute: 900)) == "All day · remind 15:00")
    }

    @Test func minutesAndPickerTimesRoundTrip() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Australia/Sydney")!
        for minute in [0, 359, 480, 1439] {
            let date = HabitForm.date(forMinute: minute, calendar: c)
            #expect(HabitForm.minute(of: date, calendar: c) == minute)
        }
    }

    // MARK: Words

    @Test func eachRefusalHasACalmSentence() {
        #expect(HabitForm.message(for: .emptyTitle) == "Give it a name first.")
        #expect(HabitForm.message(for: .targetTooSmall) == "The target needs to be at least one.")
        #expect(HabitForm.message(for: .noDays) == "Pick at least one day, or choose a number of times a week.")
        #expect(HabitForm.message(for: .windowNeedsALabel) == "Name each time of day, such as Morning or Evening.")
        #expect(HabitForm.message(for: .windowEndsBeforeItStarts) == "A time of day has to end after it starts.")
        #expect(HabitForm.message(for: .windowHasHistory) == "That time of day has history, so it stays. Archive the habit instead if you're done with it.")
        #expect(HabitForm.message(for: .tooManyWindows) == "Four times a day is the most.")
    }

    @Test func theKindsHaveTheirPlainQuestions() {
        #expect(HabitForm.question(.binary) == "Did I do it?")
        #expect(HabitForm.question(.counted) == "Did I do it N times?")
        #expect(HabitForm.question(.timed) == "Did I do it for N minutes?")
        #expect(HabitForm.question(.avoid) == "Did I avoid it?")
        #expect(HabitForm.kindName(.binary) == "Did I do it")
    }
}
