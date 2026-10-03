import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The numbers and lists Today reads: the level, the budget, the planned minutes and load state, the task
/// list at that level, and moving the slider. Midnight rollover, UTC.
@MainActor
struct TodayDayTests {

    private let utc = TimeZone(identifier: "UTC")!
    private func context() throws -> ModelContext {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        c.insert(UserSettings())
        return c
    }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }       // Oct 5 2026 is a Monday
    private func at(_ day: Int, _ hour: Int = 9) -> Date {
        DayBoundary(rolloverMinute: 0, timeZone: utc).instant(of: d(day), atMinute: hour * 60)
    }
    private func task(_ title: String, due: Int?, minutes: Int?, importance: Importance = .low, in c: ModelContext) -> TaskItem {
        let t = TaskItem(title: title, dueDate: due.map { d($0).storedDate }, effortMinutes: minutes)
        t.importanceLevel = importance
        c.insert(t)
        return t
    }
    private func overview(_ c: ModelContext, day: Int = 5, hour: Int = 9) throws -> TodayOverview {
        try TodayDay.overview(in: c, now: at(day, hour), timeZone: utc)
    }

    @Test func withNoPlanTheLevelIsTheWeekdayDefaultAndTheBudgetFollowsIt() throws {
        let c = try context()
        #expect(try overview(c, day: 5).level == .medium)                          // Monday
        #expect(try overview(c, day: 5).budgetMinutes == 180)
        #expect(try overview(c, day: 10).level == .low)                            // Saturday: weekends start low
        #expect(try overview(c, day: 10).budgetMinutes == 120)
    }

    @Test func movingTheSliderStoresTheLevelForToday() throws {
        let c = try context()
        try TodayDay.setLevel(.high, in: c, now: at(5), timeZone: utc)
        let o = try overview(c)
        #expect(o.level == .high)
        #expect(o.budgetMinutes == 240)
        try TodayDay.setLevel(.low, in: c, now: at(5), timeZone: utc)               // an upsert, not a second row
        #expect(try c.fetchCount(FetchDescriptor<DayPlan>()) == 1)
        #expect(try overview(c).level == .low)
        #expect(try overview(c, day: 6).level == .medium)                           // another day is untouched
    }

    @Test func theMeterCountsShownAndDoneTodayMinutesButNotWhatTheLevelHides() throws {
        let c = try context()
        _ = task("Draft", due: 5, minutes: 60, importance: .high, in: c)
        _ = task("Call", due: 5, minutes: 15, importance: .medium, in: c)
        let done = task("Reply", due: 5, minutes: 30, in: c)
        done.isCompleted = true; done.completedAt = at(5, 8)
        let o = try overview(c)
        #expect(o.plannedMinutes == 105)
        #expect(o.loadScore == 58)                                                   // 105 of 180
        #expect(o.state == .light)
    }

    @Test func tasksWithoutAnEstimateCountAsZeroAndAreReported() throws {
        let c = try context()
        _ = task("Draft", due: 5, minutes: 60, importance: .high, in: c)
        _ = task("Vague", due: 5, minutes: nil, importance: .high, in: c)
        let o = try overview(c)
        #expect(o.plannedMinutes == 60)
        #expect(o.missingEstimates == 1)
    }

    @Test func aFullDayReadsOverloadedAndSayingSoIsNotBlocking() throws {
        let c = try context()
        for i in 0..<5 { _ = task("T\(i)", due: 5, minutes: 45, importance: .high, in: c) }   // 225 of 180 = 125%
        let o = try overview(c)
        #expect(o.loadScore == 125)
        #expect(o.state == .overloaded)
    }

    @Test func theListFollowsTheLevelAndKeepsWhatItHidesCounted() throws {
        let c = try context()
        let urgent = task("Urgent", due: 5, minutes: 30, importance: .high, in: c)
        let later = task("Someday-ish", due: 5, minutes: 30, importance: .low, in: c)
        try TodayDay.setLevel(.low, in: c, now: at(5), timeZone: utc)
        let o = try overview(c)
        #expect(o.shown.contains { $0 === urgent })
        #expect(o.alsoToday.contains { $0 === later })
        #expect(!o.shown.contains { $0 === later })
        #expect(o.shown.count + o.alsoToday.count == 2)                             // nothing silently disappears
    }

    @Test func overdueTasksAreDueTodayAndTomorrowsAreNot() throws {
        let c = try context()
        let overdue = task("Overdue", due: 3, minutes: 15, importance: .high, in: c)
        let tomorrow = task("Tomorrow", due: 6, minutes: 15, importance: .high, in: c)
        let o = try overview(c)
        #expect(o.shown.contains { $0 === overdue })
        #expect(!o.shown.contains { $0 === tomorrow })
        #expect(o.plannedMinutes == 15)
    }

    @Test func theDayBeforeTheRolloverStillReadsAsYesterday() throws {
        let c = try context()
        let settings = try #require(try c.fetch(FetchDescriptor<UserSettings>()).first)
        settings.rolloverMinute = 180
        _ = task("Yesterday's", due: 4, minutes: 20, importance: .high, in: c)
        let o = try TodayDay.overview(in: c, now: at(5, 1), timeZone: utc)            // 01:00 on the 5th is still the 4th
        #expect(o.today == d(4))
        #expect(o.shown.count == 1)
    }
}
