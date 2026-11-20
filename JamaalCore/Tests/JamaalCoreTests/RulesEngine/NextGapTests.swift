import Foundation
import Testing
@testable import JamaalCore

/// The next gap (#410): the first free block of 20 minutes or more that ends at a fixed commitment, and the first task in Today's order that
/// fits it. Today is Thu 15 Oct 2026 (UTC), the working day 08:00 to 19:00.
@MainActor
struct NextGapTests {
    private let boundary = DayBoundary(rolloverMinute: 0, timeZone: TimeZone(identifier: "UTC")!)
    private var today: CalendarDate { CalendarDate(year: 2026, month: 10, day: 15)! }
    private func at(_ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: today, atMinute: hour * 60 + minute) }

    private func anchor(_ title: String, hour: Int, minutes: Int = 30, status: AttendanceStatus = .pending) -> Anchor {
        let a = Anchor(title: title); a.windowStart = at(hour); a.windowEnd = at(hour, minutes); a.effortMinutes = minutes; a.status = status
        return a
    }
    private func task(_ title: String, _ minutes: Int?) -> TaskItem { TaskItem(title: title, dueDate: today.storedDate, effortMinutes: minutes) }

    private func find(now: Date, anchors: [Anchor], tasks: [TaskItem]) -> NextGap? {
        NextGap.find(now: now, today: today, boundary: boundary, dayStartMinute: 8 * 60, dayEndMinute: 19 * 60, anchors: anchors, tasks: tasks)
    }

    @Test func aGapBeforeAFixedAnchorNamesItsLengthAndTheFirstTaskThatFits() throws {
        let gap = try #require(find(now: at(14), anchors: [anchor("Asr", hour: 16)], tasks: [task("Draft", 60), task("Reply", 15)]))
        #expect(gap.before == "Asr")
        #expect(gap.minutes == 120)
        #expect(gap.startsNow)
        #expect(gap.task.title == "Draft", "the first in Today's order that fits")
    }

    @Test func aTaskTooLongForTheGapIsSkippedForTheNextThatFits() throws {
        let gap = try #require(find(now: at(15, 15), anchors: [anchor("Asr", hour: 16)], tasks: [task("Big", 90), task("Small", 30)]))
        #expect(gap.minutes == 45)
        #expect(gap.task.title == "Small")
    }

    @Test func nothingThatFitsMeansNoLine() {
        #expect(find(now: at(15, 15), anchors: [anchor("Asr", hour: 16)], tasks: [task("Big", 90)]) == nil)
    }

    @Test func aTaskWithNoEstimateDoesNotCountAsFitting() {
        #expect(find(now: at(14), anchors: [anchor("Asr", hour: 16)], tasks: [task("Unknown", nil)]) == nil)
    }

    @Test func aGapThatEndsOnlyWithTheDayIsNotAGapBeforeAnything() {
        #expect(find(now: at(17), anchors: [], tasks: [task("Reply", 15)]) == nil)
        #expect(find(now: at(17), anchors: [anchor("Done", hour: 9, status: .attended)], tasks: [task("Reply", 15)]) == nil, "a decided Anchor takes no time")
    }

    @Test func aGapUnderTwentyMinutesIsNotShown() {
        #expect(find(now: at(15, 45), anchors: [anchor("Asr", hour: 16)], tasks: [task("Quick", 10)]) == nil)
    }

    @Test func insideAnAnchorTheNextGapIsTheOneAfterIt() throws {
        let asr = anchor("Asr", hour: 16, minutes: 30), maghrib = anchor("Maghrib", hour: 18)
        let gap = try #require(find(now: at(16, 10), anchors: [asr, maghrib], tasks: [task("Reply", 30)]))
        #expect(gap.before == "Maghrib")
        #expect(!gap.startsNow)
        #expect(gap.start == at(16, 30))
        #expect(gap.minutes == 90)
    }

    @Test func aCompletedTaskIsNeverOffered() throws {
        let done = task("Done", 15); done.isCompleted = true
        let gap = try #require(find(now: at(14), anchors: [anchor("Asr", hour: 16)], tasks: [done, task("Open", 15)]))
        #expect(gap.task.title == "Open")
    }
}
