import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// When Today offers Night Planning: the morning card (no plan for today) and the evening row (tonight not yet
/// planned or skipped). Midnight rollover, UTC, day 08:00 to 19:00, planning prompt at 20:00. Wed 14 Oct 2026.
@MainActor
struct PlanningPromptTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }
    private func context() throws -> ModelContext {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        c.insert(UserSettings())                                          // day 08:00–19:00, planning prompt 20:00
        return c
    }
    private func session(_ c: ModelContext, for day: Int, complete: Bool = false, skipped: Bool = false) {
        let s = NightPlanningSession()
        s.forDate = d(day).storedDate
        s.isComplete = complete
        if skipped { s.skippedAt = at(day - 1, 21) }
        c.insert(s)
    }
    private func morningDue(_ c: ModelContext, _ now: Date) throws -> Bool {
        try MorningCard.isDue(now: now, boundary: boundary, context: c)
    }
    private func eveningDue(_ c: ModelContext, _ now: Date) throws -> Bool {
        try NightPlanning.eveningPromptDue(now: now, boundary: boundary, context: c)
    }

    // MARK: Morning card

    @Test func withNoPlanForTodayTheCardIsDue() throws {
        let c = try context()
        #expect(try morningDue(c, at(14, 9)))
    }

    @Test func aConfirmedPlanForTodayMeansNoCard() throws {
        let c = try context()
        session(c, for: 14, complete: true)
        #expect(try !morningDue(c, at(14, 9)))
    }

    @Test func aSkippedOrUnfinishedPlanStillGetsTheCard() throws {
        let c = try context()
        session(c, for: 14, skipped: true)
        #expect(try morningDue(c, at(14, 9)))
        let c2 = try context()
        session(c2, for: 14)                                              // started, never closed
        #expect(try morningDue(c2, at(14, 9)))
    }

    @Test func aPlanForAnotherDayDoesNotCount() throws {
        let c = try context()
        session(c, for: 15, complete: true)
        session(c, for: 13, complete: true)
        #expect(try morningDue(c, at(14, 9)))
    }

    @Test func dismissingPutsItAwayForTheRestOfTheDayOnly() throws {
        let c = try context()
        try MorningCard.markShown(now: at(14, 9), boundary: boundary, context: c)
        #expect(try morningDue(c, at(14, 10)))                           // shown but not acted on: still there
        try MorningCard.dismiss(now: at(14, 10), boundary: boundary, context: c)
        #expect(try !morningDue(c, at(14, 11)))
        #expect(try morningDue(c, at(15, 9)))                            // tomorrow is a fresh day
    }

    @Test func showingItTwiceLogsItOnce() throws {
        let c = try context()
        try MorningCard.markShown(now: at(14, 9), boundary: boundary, context: c)
        try MorningCard.markShown(now: at(14, 9, 30), boundary: boundary, context: c)
        let logs = try c.fetch(FetchDescriptor<NudgeLog>()).filter { $0.nudgeKind == .morningPlanCard }
        #expect(logs.count == 1)
        #expect(logs.first?.subjectKey == d(14).isoString)
    }

    @Test func itIsNotOfferedOnceTheWorkingDayIsOver() throws {
        let c = try context()
        #expect(try morningDue(c, at(14, 18, 59)))
        #expect(try !morningDue(c, at(14, 19)))
        #expect(try !morningDue(c, at(14, 22)))
    }

    @Test func dismissingWithoutAnEarlierLogStillRecordsIt() throws {
        let c = try context()
        try MorningCard.dismiss(now: at(14, 9), boundary: boundary, context: c)
        #expect(try !morningDue(c, at(14, 9, 5)))
    }

    // MARK: Evening row

    @Test func theRowAppearsAtThePlanningTimeAndNotBefore() throws {
        let c = try context()
        #expect(try !eveningDue(c, at(14, 19, 59)))
        #expect(try eveningDue(c, at(14, 20)))
        #expect(try eveningDue(c, at(14, 23, 30)))
    }

    @Test func itStaysThroughTheSmallHoursUntilTheNextDayStarts() throws {
        let c = try context()
        #expect(try eveningDue(c, at(15, 1)))                             // 01:00 on the 15th: still tonight
        #expect(try eveningDue(c, at(15, 7, 59)))
        #expect(try !eveningDue(c, at(15, 9)))                           // the day has begun
    }

    @Test func plannedOrSkippedTonightMeansNoRow() throws {
        let c = try context()
        session(c, for: 15, complete: true)                               // tomorrow's plan is confirmed
        #expect(try !eveningDue(c, at(14, 21)))
        let c2 = try context()
        session(c2, for: 15, skipped: true)
        #expect(try !eveningDue(c2, at(14, 21)))
    }

    @Test func aStartedButUnfinishedPlanStillGetsTheRow() throws {
        let c = try context()
        session(c, for: 15)
        #expect(try eveningDue(c, at(14, 21)))
    }

    @Test func theSmallHoursUseTheSessionForThatMorning() throws {
        let c = try context()
        session(c, for: 15, complete: true)
        #expect(try !eveningDue(c, at(15, 1)))                            // planned for the 15th, and it's 01:00 on the 15th
    }
}
