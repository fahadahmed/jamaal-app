import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Today's Anchors section (docs/journeys/today-list.md, item 3): plain and grouped rows, composed titles,
/// window state and progress, the count and the next window of a group, and multi-day windows.
@MainActor
struct TodayAnchorsTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }
    private func items(_ c: ModelContext, now: Date) throws -> [TodayAnchorItem] {
        try TodayAnchors.items(in: c, now: now, boundary: boundary)
    }

    @discardableResult
    private func anchor(
        _ title: String, rule: AnchorRule? = nil, day: Int = 15, from: Date, to: Date, minutes: Int? = nil,
        status: AttendanceStatus = .pending, in c: ModelContext
    ) -> Anchor {
        let a = Anchor(title: title)
        a.occurrenceDate = d(day).storedDate
        a.windowStart = from; a.windowEnd = to; a.effortMinutes = minutes
        a.status = status
        a.rule = rule
        c.insert(a)
        return a
    }
    private func rule(_ title: String, in c: ModelContext) -> AnchorRule { let r = AnchorRule(title: title); c.insert(r); return r }

    @Test func oneOffsAndSingleAnchorsArePlainRowsSortedByWindowStart() throws {
        let c = try context()
        anchor("Dentist", from: at(15, 15), to: at(15, 16), in: c)
        anchor("Bins", rule: rule("Bin night", in: c), from: at(15, 8), to: at(15, 9), in: c)
        let list = try items(c, now: at(15, 7))
        #expect(list.count == 2)
        guard case .plain(let first) = list[0], case .plain(let second) = list[1] else { Issue.record("expected plain rows"); return }
        #expect(first.anchor.title == "Bins")
        #expect(second.title == "Dentist")
    }

    @Test func aPlainRowAddsTheSlotLabelOnlyWhenItDiffersFromTheRule() throws {
        let c = try context()
        let school = rule("School run", in: c)
        anchor("Drop-off", rule: school, from: at(15, 8), to: at(15, 9), in: c)
        anchor("Bin night", rule: rule("Bin night", in: c), from: at(15, 19), to: at(15, 21), in: c)
        let list = try items(c, now: at(15, 7))
        guard case .plain(let a) = list[0], case .plain(let b) = list[1] else { Issue.record("expected plain rows"); return }
        #expect(a.title == "School run · Drop-off")
        #expect(b.title == "Bin night")
    }

    @Test func aRuleWithSeveralAnchorsTodayIsOneGroupWithACountAndTheNextWindow() throws {
        let c = try context()
        let salah = rule("Salah", in: c)
        anchor("Fajr", rule: salah, from: at(15, 5), to: at(15, 6, 30), status: .attended, in: c)
        anchor("Dhuhr", rule: salah, from: at(15, 12), to: at(15, 15, 32), in: c)
        anchor("Asr", rule: salah, from: at(15, 15, 40), to: at(15, 17, 58), in: c)
        let list = try items(c, now: at(15, 13))
        #expect(list.count == 1)
        guard case .group(let g) = list[0] else { Issue.record("expected a group"); return }
        #expect(g.title == "Salah")
        #expect(g.members.map(\.anchor.title) == ["Fajr", "Dhuhr", "Asr"])
        #expect(g.members.map(\.title) == ["Fajr", "Dhuhr", "Asr"])         // by slot label, not "Salah · Fajr"
        #expect(g.attended == 1)
        #expect(g.counting == 3)
        #expect(g.next?.anchor.title == "Dhuhr")
        #expect(!g.isAllDecided)
    }

    @Test func skippedAndDelegatedLeaveTheDenominatorButMissedStaysInIt() throws {
        let c = try context()
        let salah = rule("Salah", in: c)
        anchor("Fajr", rule: salah, from: at(15, 5), to: at(15, 6), status: .skipped, in: c)
        anchor("Dhuhr", rule: salah, from: at(15, 12), to: at(15, 13), status: .delegated, in: c)
        anchor("Asr", rule: salah, from: at(15, 15), to: at(15, 16), in: c)           // closed and pending by 20:00: reads missed
        anchor("Maghrib", rule: salah, from: at(15, 17), to: at(15, 18), status: .attended, in: c)
        let list = try items(c, now: at(15, 20))
        guard case .group(let g) = list[0] else { Issue.record("expected a group"); return }
        #expect(g.counting == 2)
        #expect(g.attended == 1)
        #expect(g.members.first { $0.anchor.title == "Asr" }?.status == .missed)
    }

    @Test func aGroupWithEverythingDecidedHasNoNextAndReadsAllDecided() throws {
        let c = try context()
        let school = rule("School run", in: c)
        anchor("Drop-off", rule: school, from: at(15, 8), to: at(15, 9), status: .attended, in: c)
        anchor("Pick-up", rule: school, from: at(15, 15), to: at(15, 16), status: .delegated, in: c)
        let list = try items(c, now: at(15, 10))
        guard case .group(let g) = list[0] else { Issue.record("expected a group"); return }
        #expect(g.next == nil)
        #expect(g.isAllDecided)
    }

    @Test func groupsSortByTheirEarliestWindowStartAmongPlainRows() throws {
        let c = try context()
        anchor("Dentist", from: at(15, 9), to: at(15, 10), in: c)
        let salah = rule("Salah", in: c)
        anchor("Fajr", rule: salah, from: at(15, 5), to: at(15, 6), in: c)
        anchor("Dhuhr", rule: salah, from: at(15, 12), to: at(15, 13), in: c)
        let list = try items(c, now: at(15, 4))
        guard case .group = list[0], case .plain = list[1] else { Issue.record("group should sort first"); return }
    }

    @Test func windowStateAndProgressFollowTheClock() throws {
        let c = try context()
        let a = anchor("School run", from: at(15, 8), to: at(15, 10), in: c)
        func row(_ now: Date) throws -> TodayAnchorRow {
            guard case .plain(let r) = try items(c, now: now)[0] else { throw CocoaError(.fileReadUnknown) }
            return r
        }
        #expect(try row(at(15, 7)).state == .upcoming)
        #expect(try row(at(15, 7)).progress == 0)
        #expect(try row(at(15, 9)).state == .open)
        #expect(abs(try row(at(15, 9)).progress - 0.5) < 0.0001)
        #expect(try row(at(15, 9, 45)).state == .closingSoon)
        #expect(try row(at(15, 11)).state == .closed)
        #expect(try row(at(15, 11)).progress == 1)
        #expect(try row(at(15, 11)).status == .missed)                               // closed while pending reads missed at once
        _ = a
    }

    @Test func aMultiDayWindowStaysOnTodayWhileItIsOpenAndPending() throws {
        let c = try context()
        let plants = rule("Water the plants", in: c)
        anchor("Water the plants", rule: plants, day: 13, from: at(13, 0), to: at(17, 0), in: c)   // opened two days ago, open through the 16th
        let list = try items(c, now: at(15, 9))
        #expect(list.count == 1)
        guard case .plain(let r) = list[0] else { Issue.record("expected a plain row"); return }
        #expect(r.dayNumber == 3)                                                     // 13th, 14th, 15th: day 3 of 4
        #expect(r.totalDays == 4)
        #expect(r.endsToday == false)
    }

    @Test func aMultiDayWindowThatIsDecidedOrClosedDoesNotCarryOver() throws {
        let c = try context()
        let plants = rule("Water the plants", in: c)
        anchor("Water the plants", rule: plants, day: 12, from: at(12, 0), to: at(14, 0), status: .attended, in: c)
        anchor("Feed the cat", rule: rule("Cat", in: c), day: 12, from: at(12, 0), to: at(14, 0), in: c)   // closed, pending
        #expect(try items(c, now: at(15, 9)).isEmpty)
    }

    @Test func anAlreadyDecidedMultiDayWindowDoesNotCarryOverEvenWhileOpen() throws {
        let c = try context()
        anchor("Water the plants", rule: rule("Plants", in: c), day: 13, from: at(13, 0), to: at(17, 0), status: .attended, in: c)
        #expect(try items(c, now: at(15, 9)).isEmpty)
    }

    @Test func tomorrowsAndYesterdaysAnchorsAreNotToday() throws {
        let c = try context()
        anchor("Tomorrow", day: 16, from: at(16, 8), to: at(16, 9), in: c)
        anchor("Yesterday", day: 14, from: at(14, 8), to: at(14, 9), status: .attended, in: c)
        #expect(try items(c, now: at(15, 7)).isEmpty)
    }

    @Test func aSingleDayWindowIsOneDayLong() throws {
        let c = try context()
        anchor("Dentist", from: at(15, 15), to: at(15, 16), in: c)
        guard case .plain(let r) = try items(c, now: at(15, 7))[0] else { Issue.record("expected a plain row"); return }
        #expect(r.totalDays == 1)
        #expect(r.dayNumber == 1)
        #expect(r.endsToday)
    }
}

/// What a person can do with an Anchor row right now (AN-10), and doing it.
@MainActor
struct TodayAnchorActionTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }
    private func anchor(_ status: AttendanceStatus = .pending) -> Anchor {
        let a = Anchor(title: "School run")
        a.occurrenceDate = d(15).storedDate
        a.windowStart = at(15, 8); a.windowEnd = at(15, 10)
        a.status = status
        return a
    }
    private func actions(_ a: Anchor, now: Date) -> [AnchorAction] { TodayAnchors.actions(for: a, now: now, boundary: boundary) }

    @Test func upcomingCanBeSkippedOrDelegatedButNotAttended() {
        #expect(actions(anchor(), now: at(15, 7)) == [.notToday, .someoneElseDidIt])
    }

    @Test func anOpenWindowOffersAllThree() {
        #expect(actions(anchor(), now: at(15, 9)) == [.attended, .notToday, .someoneElseDidIt])
        #expect(actions(anchor(), now: at(15, 9, 50)) == [.attended, .notToday, .someoneElseDidIt])     // closing soon
    }

    @Test func aDecidedAnchorOffersOnlyUndoWhileItsWindowIsOpen() {
        for status in [AttendanceStatus.attended, .skipped, .delegated] {
            #expect(actions(anchor(status), now: at(15, 9)) == [.undo])
            #expect(actions(anchor(status), now: at(15, 11)).isEmpty)
        }
    }

    @Test func aMissedAnchorOffersDoneAfterAllUntilTheEndOfThatDay() {
        #expect(actions(anchor(), now: at(15, 11)) == [.markDoneAfterAll])                // closed while pending
        #expect(actions(anchor(.missed), now: at(15, 23)) == [.markDoneAfterAll])
        #expect(actions(anchor(.missed), now: at(16, 1)).isEmpty)
    }

    @Test func performingAnActionWritesTheStatusAndTheTime() throws {
        let a = anchor()
        try TodayAnchors.perform(.attended, on: a, now: at(15, 9), boundary: boundary)
        #expect(a.status == .attended)
        #expect(a.resolvedAt == at(15, 9))
        try TodayAnchors.perform(.undo, on: a, now: at(15, 9, 5), boundary: boundary)
        #expect(a.status == .pending)
        try TodayAnchors.perform(.notToday, on: a, now: at(15, 9, 6), boundary: boundary)
        #expect(a.status == .skipped)
        try TodayAnchors.perform(.undo, on: a, now: at(15, 9, 7), boundary: boundary)
        try TodayAnchors.perform(.someoneElseDidIt, on: a, now: at(15, 9, 8), boundary: boundary)
        #expect(a.status == .delegated)
    }

    @Test func attendingBeforeTheWindowOpensIsRefused() {
        let a = anchor()
        #expect(throws: AnchorAttendance.LogError.notOpenYet) {
            try TodayAnchors.perform(.attended, on: a, now: at(15, 7), boundary: boundary)
        }
        #expect(a.status == .pending)
    }

    @Test func markingDoneAfterAllReopensNothingElse() throws {
        let a = anchor()
        try TodayAnchors.perform(.markDoneAfterAll, on: a, now: at(15, 12), boundary: boundary)
        #expect(a.status == .attended)
        let skipped = anchor(.skipped)
        #expect(actions(skipped, now: at(15, 12)).isEmpty)
    }
}
