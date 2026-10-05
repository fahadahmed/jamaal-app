//
//  AnchorsCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The Anchors tab's words: a one-line summary per rule, its state, exceptions and the next Anchor.
struct AnchorsCopyTests {
    private var utc: TimeZone { TimeZone(identifier: "UTC")! }
    private func d(_ day: Int, month: Int = 10) -> CalendarDate { CalendarDate(year: 2026, month: month, day: day)! }          // 15 Oct 2026 is a Thursday
    private func slot(_ label: String, _ start: String, _ minutes: Int, allDay: Bool = false) -> AnchorSlot {
        AnchorSlot(id: label, label: label, start: start, windowMinutes: minutes, allDay: allDay)
    }
    private func next(_ day: Int, _ hour: Int, _ minute: Int = 0, title: String = "X") -> GeneratedAnchor {
        let boundary = DayBoundary(rolloverMinute: 0, timeZone: utc)
        let start = boundary.instant(of: d(day), atMinute: hour * 60 + minute)
        return GeneratedAnchor(title: title, occurrenceDate: d(day), slotKey: "s", windowStart: start, windowEnd: start.addingTimeInterval(1800),
                               effortMinutes: nil, remindBeforeStartMinutes: nil, remindBeforeEndMinutes: nil)
    }
    private func line(_ config: ScheduledConfig, next: GeneratedAnchor? = nil) -> String {
        AnchorsCopy.scheduleLine(config, next: next, today: d(15), style: TodayCopy.TimeStyle(timeZone: utc, locale: Locale(identifier: "en_GB")))
    }

    @Test func daysReadAsRangesNamesOrAPlural() {
        #expect(AnchorsCopy.days([1, 2, 3, 4, 5]) == "Mon–Fri")
        #expect(AnchorsCopy.days([1, 2, 3, 4, 5, 6, 7]) == "Every day")
        #expect(AnchorsCopy.days([2]) == "Tuesdays")
        #expect(AnchorsCopy.days([1, 3, 5]) == "Mon, Wed, Fri")
        #expect(AnchorsCopy.days([6, 7]) == "Sat, Sun")
        #expect(AnchorsCopy.days([2, 3, 4]) == "Tue–Thu")
    }

    @Test func aSchoolRunListsItsNamedTimes() {
        let config = ScheduledConfig(recurrence: .weekly(weekdays: [1, 2, 3, 4, 5]),
                                     slots: [slot("Drop-off", "08:15", 30), slot("Pick-up", "15:00", 30)])
        #expect(line(config) == "Mon–Fri · drop-off 08:15, pick-up 15:00")
    }

    @Test func aSingleTimeShowsItsWindowAndTheNextOccurrence() {
        let config = ScheduledConfig(recurrence: .weekly(weekdays: [2]), slots: [slot("Bin night", "19:00", 240)])
        #expect(line(config, next: next(16, 19)) == "Tuesdays · 19:00–23:00 · next tomorrow")
        #expect(line(config, next: next(20, 19)) == "Tuesdays · 19:00–23:00 · next Tue")
        #expect(line(config) == "Tuesdays · 19:00–23:00")
    }

    @Test func everyNDaysAndWeeksSayHowOften() {
        #expect(line(ScheduledConfig(recurrence: .everyNDays(n: 3, startDate: d(1)), slots: [slot("Gym", "06:30", 60)])) == "Every 3 days · 06:30–07:30")
        #expect(line(ScheduledConfig(recurrence: .everyNDays(n: 1, startDate: d(1)), slots: [slot("Gym", "06:30", 60)])) == "Every day · 06:30–07:30")
        #expect(line(ScheduledConfig(recurrence: .everyNWeeks(n: 2, weekdays: [4], startDate: d(1)), slots: [slot("Choir", "19:00", 60)])) == "Every 2 weeks, Thursdays · 19:00–20:00")
    }

    @Test func anAfterLastRuleSaysTheIntervalAndWhenItIsOpen() {
        let config = ScheduledConfig(recurrence: .afterLast(minDays: 3, maxDays: 4, startDate: d(12)), slots: [AnchorSlot(id: "a", label: "", start: "00:00", windowMinutes: 0, allDay: true)])
        let open = GeneratedAnchor(title: "Water", occurrenceDate: d(15), slotKey: "a", windowStart: Date(), windowEnd: DayBoundary(rolloverMinute: 0, timeZone: utc).instant(of: d(16), atMinute: 1439), effortMinutes: nil, remindBeforeStartMinutes: nil, remindBeforeEndMinutes: nil)
        #expect(line(config, next: open) == "3–4 days after last · open until Fri")
        #expect(line(config) == "3–4 days after last")
        let same = ScheduledConfig(recurrence: .afterLast(minDays: 3, maxDays: 3, startDate: d(12)), slots: config.slots)
        #expect(line(same) == "3 days after last")
    }

    @Test func allDayTimesSaySo() {
        let config = ScheduledConfig(recurrence: .weekly(weekdays: [6]), slots: [slot("Tidy", "00:00", 0, allDay: true)])
        #expect(line(config) == "Saturdays · all day")
    }

    @Test func aPausedRuleSaysWhyAndUntilWhen() {
        #expect(AnchorsCopy.state(.paused(reason: .holiday, until: d(2, month: 6))) == "Paused · holiday · until Tue 2 Jun")
        #expect(AnchorsCopy.state(.paused(reason: .travel, until: nil)) == "Paused · travel · until you resume")
        #expect(AnchorsCopy.state(.paused(reason: .other, until: d(18))) == "Paused · until Sun 18 Oct")
        #expect(AnchorsCopy.state(.paused(reason: .term, until: d(18))) == "Paused · term break · until Sun 18 Oct")
    }

    @Test func aRuleThatNeedsAttentionSaysWhatToDo() {
        #expect(AnchorsCopy.state(.needsAttention(.newerVersion)) == "Needs attention · update Jamaal to see it")
        #expect(AnchorsCopy.state(.needsAttention(.unreadable)) == "Needs attention · this rule couldn't be read")
        #expect(AnchorsCopy.state(.active) == nil)
    }

    @Test func exceptionsReadAsARangeWithTheirReason() {
        #expect(AnchorsCopy.exception(AnchorException(from: d(20), to: d(24), reason: "holiday")) == "Holiday · 20 Oct – 24 Oct")
        #expect(AnchorsCopy.exception(AnchorException(from: d(20), to: d(20), reason: "illness")) == "Illness · 20 Oct")
        #expect(AnchorsCopy.exception(AnchorException(from: d(20), to: nil, reason: "travel")) == "Travel · from 20 Oct, until you resume")
        #expect(AnchorsCopy.reasonTitle(.term) == "Term break")
        #expect(AnchorsCopy.reasonTitle(.other) == "Other")
    }

    @Test func theTypesHaveNamesAndHints() {
        #expect(AnchorsCopy.typeTitle(.schoolRun) == "School run")
        #expect(AnchorsCopy.typeTitle(.binNight) == "Bin night")
        #expect(AnchorsCopy.typeTitle(.plantWatering) == "Plant watering")
        #expect(AnchorsCopy.typeTitle(.custom) == "Something else")
        #expect(AnchorsCopy.typeHint(.schoolRun) == "Drop-off and pick-up on school days.")
        #expect(AnchorsCopy.typeHint(.plantWatering) == "Every few days, from when you last did it.")
    }

    @Test func eachRefusalHasACalmSentence() {
        #expect(AnchorsCopy.message(for: .emptyTitle) == "Give it a name first.")
        #expect(AnchorsCopy.message(for: .noDays) == "Pick at least one day.")
        #expect(AnchorsCopy.message(for: .noTime) == "Add at least one time.")
        #expect(AnchorsCopy.message(for: .badInterval) == "Check the numbers: an interval is at least one day, and the longest is never shorter than the shortest.")
        #expect(AnchorsCopy.message(for: .slotNeedsALabel) == "Name each time, such as Drop-off or Pick-up.")
        #expect(AnchorsCopy.message(for: .windowTooShort) == "A time needs a window of at least a minute.")
        #expect(AnchorsCopy.message(for: .endsBeforeItStarts) == "The end has to come after the start.")
        #expect(AnchorsCopy.message(for: .endsInThePast) == "That window has already closed.")
        #expect(AnchorsCopy.message(for: .notAScheduledRule) == "This kind of rule can't be edited here yet.")
    }

    @Test func upcomingDaysAreLabelledWithTheDayAndTime() {
        let style = TodayCopy.TimeStyle(timeZone: utc, locale: Locale(identifier: "en_GB"))
        #expect(AnchorsCopy.upcoming(next(16, 8, 15), today: d(15), style: style) == "Tomorrow · 8:15")
        #expect(AnchorsCopy.upcoming(next(15, 19), today: d(15), style: style) == "Today · 19:00")
        #expect(AnchorsCopy.upcoming(next(19, 8, 15), today: d(15), style: style) == "Mon 19 Oct · 8:15")
    }
}
