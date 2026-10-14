import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Once Isha, the last prayer of the day, is done, Salah has nothing left to say for that day: Today's row reads as done, and the
/// Anchors list doesn't offer that same Isha as the rule's "next" (its window runs past midnight, so it is still open).
@MainActor
struct SalahDayEndTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }
    private let leicester = PrayerConfig.Location(mode: "device", latitude: 52.64, longitude: -1.14, name: "Leicester")

    /// A Salah rule with its Anchors for the 15th to the 17th of October, and the Isha of the 15th.
    private func world() throws -> (context: ModelContext, rule: AnchorRule, isha: Anchor) {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        var p = PrayerRuleDraft(countryCode: "GB")
        p.location = leicester
        let rule = try PrayerEditing.create(p, in: c, now: at(15, 9))
        try AnchorGenerator.sync(in: c, boundary: boundary, now: at(15, 9), horizonDays: 3)
        let all = try c.fetch(FetchDescriptor<Anchor>())
        let isha = try #require(all.first { $0.slotKey == "isha" && CalendarDate(storedDate: $0.occurrenceDate) == d(15) })
        return (c, rule, isha)
    }

    /// The moment after Isha opened and before it closes (it closes past midnight).
    private func eveningNow(_ isha: Anchor) -> Date { isha.windowStart.addingTimeInterval(3600) }

    private func next(_ c: ModelContext, now: Date) throws -> GeneratedAnchor? {
        try AnchorsOverview.read(in: c, now: now, boundary: boundary).rows.first?.next
    }

    @Test func anIshaStillToDoIsTheRulesNext() throws {
        let (c, _, isha) = try world()
        let upcoming = try #require(try next(c, now: eveningNow(isha)))
        #expect(upcoming.slotKey == "isha" && upcoming.occurrenceDate == d(15))
    }

    @Test func onceIshaIsAttendedTheNextIsTomorrowsFirstPrayerNotThatSameIsha() throws {
        let (c, _, isha) = try world()
        let now = eveningNow(isha)
        try AnchorAttendance.attend(isha, at: now)
        let upcoming = try #require(try next(c, now: now))
        #expect(upcoming.occurrenceDate == d(16), "the 15th is done")
        #expect(upcoming.slotKey == "fajr")
    }

    @Test(arguments: [AttendanceStatus.skipped, .delegated])
    func skippedOrSomeoneElseDidItCountsAsDoneToo(_ status: AttendanceStatus) throws {
        let (c, _, isha) = try world()
        let now = eveningNow(isha)
        if status == .skipped { try AnchorAttendance.skip(isha, at: now) } else { try AnchorAttendance.delegate(isha, at: now) }
        let upcoming = try #require(try next(c, now: now))
        #expect(upcoming.occurrenceDate == d(16))
    }

    @Test func undoingIshaPutsItBackAsNext() throws {
        let (c, _, isha) = try world()
        let now = eveningNow(isha)
        try AnchorAttendance.attend(isha, at: now)
        try AnchorAttendance.undo(isha, at: now)
        let upcoming = try #require(try next(c, now: now))
        #expect(upcoming.slotKey == "isha" && upcoming.occurrenceDate == d(15))
    }

    @Test func todaysSalahRowReadsAsDoneAfterIsha() throws {
        let (c, _, isha) = try world()
        let now = eveningNow(isha)
        try AnchorAttendance.attend(isha, at: now)
        let items = try TodayAnchors.items(in: c, now: now, boundary: boundary)
        guard case .group(let group) = try #require(items.first) else { Issue.record("expected the Salah group"); return }
        #expect(group.isAllDecided)
        #expect(group.next == nil)
    }
}
