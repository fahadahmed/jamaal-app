import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Coming up (docs/journeys/coming-up-and-day-review.md): tasks due after today, by day for 14 days, then Later.
/// Today is Thu 15 Oct 2026 (UTC).
@MainActor
struct ComingUpTests {
    private func read(_ w: TaskWorld) throws -> ComingUp {
        try ComingUp.read(in: w.context, today: w.d(15), boundary: w.boundary)
    }

    @Test func listsOnlyLiveTasksDueAfterToday() throws {
        let w = try TaskWorld()
        w.task("Today", due: 15)
        w.task("Overdue", due: 12)
        w.task("Backlog")
        w.task("Tomorrow", due: 16)
        let done = w.task("Done", due: 17); done.isCompleted = true; done.completedAt = w.at(15)
        let dropped = w.task("Dropped", due: 17); dropped.droppedAt = w.at(15)
        let c = try read(w)
        #expect(c.days.flatMap(\.items).count == 1)
        #expect(c.count == 1)
        #expect(c.days.first?.date == w.d(16))
        _ = (done, dropped)
    }

    @Test func groupsByDayWithHowFarAheadEachIs() throws {
        let w = try TaskWorld()
        w.task("B", due: 17, created: 3)
        w.task("A", due: 17, created: 2)
        w.task("T", due: 16)
        w.task("N", due: 22)
        let c = try read(w)
        #expect(c.days.map(\.date) == [w.d(16), w.d(17), w.d(22)])
        #expect(c.days.map(\.daysAhead) == [1, 2, 7])
        #expect(c.days[1].items.map(\.title) == ["A", "B"], "in a day, the older task first")
    }

    @Test func theNextFourteenDaysAreInTheListAndAnythingLaterIsCollapsedUnderLater() throws {
        let w = try TaskWorld()
        w.task("Edge", due: 29)             // 14 days ahead
        w.task("Past the edge", due: 30)    // 15 days ahead
        w.task("Far", due: 31)
        let c = try read(w)
        #expect(c.days.map(\.date) == [w.d(29)])
        #expect(c.later.map(\.title) == ["Past the edge", "Far"])
        #expect(c.count == 1, "the row counts the next 14 days only")
        #expect(c.laterCount == 2)
    }

    @Test func oneOffAnchorsAppearWithTheirTimeButRecurringOnesNever() throws {
        let w = try TaskWorld()
        let oneOff = Anchor(title: "Dentist")
        oneOff.occurrenceDate = w.d(17).storedDate; oneOff.windowStart = w.at(17, 14); oneOff.windowEnd = w.at(17, 15)
        w.context.insert(oneOff)
        let recurring = Anchor(title: "Bin night")
        recurring.occurrenceDate = w.d(16).storedDate; recurring.windowStart = w.at(16, 19); recurring.windowEnd = w.at(16, 22)
        w.context.insert(recurring)
        let rule = AnchorRule(title: "Bins"); w.context.insert(rule); recurring.rule = rule
        w.task("Report", due: 17)
        let c = try read(w)
        #expect(c.days.map(\.date) == [w.d(17)])
        #expect(c.days[0].items.map(\.title) == ["Dentist", "Report"], "an Anchor comes first, by its time, then tasks")
        #expect(c.days[0].items[0].isOneOffAnchor)
        #expect(c.count == 2)
    }

    @Test func aRepeatingTaskShowsItsOneLiveInstance() throws {
        let w = try TaskWorld()
        let series = UUID()
        let live = w.task("Timesheet", due: 16); live.repeatKind = "weekly"; live.seriesID = series
        let old = w.task("Timesheet", due: 9); old.repeatKind = "weekly"; old.seriesID = series; old.isCompleted = true; old.completedAt = w.at(9)
        let c = try read(w)
        #expect(c.count == 1)
        _ = old
    }

    @Test func aTaskTickedWhileTheScreenIsOpenStaysListedSoTheTickCanBeTakenBack() throws {
        let w = try TaskWorld()
        let t = w.task("Groceries", due: 16); t.isCompleted = true; t.completedAt = w.at(15)
        #expect(try ComingUp.read(in: w.context, today: w.d(15), boundary: w.boundary).count == 0)
        #expect(try ComingUp.read(in: w.context, today: w.d(15), boundary: w.boundary, keeping: [t.id]).count == 1)
    }

    @Test func theTodayRowSaysHowManyAndStaysWhenThereAreNone() throws {
        let w = try TaskWorld()
        #expect(try read(w).count == 0)
        #expect(try read(w).days.isEmpty)
        w.task("One", due: 16)
        #expect(try read(w).count == 1)
    }
}
