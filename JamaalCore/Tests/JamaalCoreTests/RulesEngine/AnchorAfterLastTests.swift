import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// `afterLast` (docs/schema/anchor.md): an interval from the last time something was handled, not
/// the calendar — plants "every 3–4 days". Exactly one live instance per slot, all-day, flexible.
@MainActor
struct AnchorAfterLastTests {

    /// Plants: opens 3 days after last handled, closes at the end of day 4. Last handled Mon 5 Oct.
    private func plants(
        _ w: AnchorWorld, lastHandled: Int = 5, createdOn: Int = 1,
        exceptions: [AnchorException] = [], endDate: CalendarDate? = nil, month: Int = 10
    ) -> AnchorRule {
        let config = w.scheduled(
            .afterLast(minDays: 3, maxDays: 4, startDate: w.d(lastHandled, month: month)),
            slots: [w.slot("water", "", "00:00", minutes: 1, allDay: true)],
            endDate: endDate, exceptions: exceptions
        )
        return w.rule("Water the plants", config, effort: 10, createdAt: w.at(createdOn, 0), source: .plantWatering)
    }

    private func sync(_ w: AnchorWorld, day: Int, hour: Int = 9) throws -> AnchorSyncReport {
        try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: w.at(day, hour))
    }

    private func start(_ w: AnchorWorld, _ day: Int) -> Date { w.boundary.startInstant(of: w.d(day)) }

    // MARK: The first window

    @Test func theFirstWindowOpensMinDaysAfterLastHandledAndClosesAtTheEndOfDayMaxDays() throws {
        let w = try AnchorWorld()
        _ = plants(w)
        let report = try sync(w, day: 5)
        #expect(report.created == 1)                                   // created at once, though it opens in 3 days
        let anchor = try #require(try w.anchors().first)
        #expect(anchor.occurrenceDate == w.d(8).storedDate)            // the day it opened
        #expect(anchor.windowStart == start(w, 8))
        #expect(anchor.windowEnd == start(w, 10))                      // end of day 9: open over two days
        #expect(anchor.slotKey == "water")
        #expect(anchor.title == "Water the plants")
        #expect(anchor.effortMinutes == 10)
    }

    @Test func thereIsExactlyOneLiveInstanceSoSyncingAgainChangesNothing() throws {
        let w = try AnchorWorld()
        _ = plants(w)
        _ = try sync(w, day: 5)
        #expect(try sync(w, day: 6) == AnchorSyncReport())
        #expect(try sync(w, day: 9) == AnchorSyncReport())             // still open and pending
        #expect(try w.anchors().count == 1)
    }

    @Test func aLastHandledDateOlderThanTheRuleIsTreatedAsDueNow() throws {
        let w = try AnchorWorld()
        _ = plants(w, lastHandled: 20, createdOn: 5, month: 9)         // last done 20 Sep; the rule is made on 5 Oct
        _ = try sync(w, day: 5)
        let anchor = try #require(try w.anchors().first)
        #expect(anchor.windowStart == start(w, 5))                     // opens today, same two-day length
        #expect(anchor.windowEnd == start(w, 7))
    }

    // MARK: The next window

    @Test(arguments: [AttendanceStatus.attended, .skipped, .delegated])
    func theNextWindowOpensMinDaysAfterTheDayItWasHandled(status: AttendanceStatus) throws {
        let w = try AnchorWorld()
        _ = plants(w)
        _ = try sync(w, day: 5)
        let first = try #require(try w.anchors().first)
        first.status = status
        first.resolvedAt = w.at(9, 18)                                  // handled on the 9th, evening
        let report = try sync(w, day: 9, hour: 19)
        #expect(report.created == 1)
        let next = try #require(try w.anchors().last)
        #expect(next.windowStart == start(w, 12))                       // 9 + 3
        #expect(next.windowEnd == start(w, 14))
        #expect(try w.anchors().count == 2)
    }

    @Test func handlingItEarlyBringsTheNextWindowForwardWithIt() throws {
        let w = try AnchorWorld()
        _ = plants(w)
        _ = try sync(w, day: 5)
        let first = try #require(try w.anchors().first)
        first.status = .attended
        first.resolvedAt = w.at(8, 7)                                   // the first day it opened
        _ = try sync(w, day: 8)
        #expect(try w.anchors().last?.windowStart == start(w, 11))      // 8 + 3
    }

    @Test func aMissedWindowOpensTheNextOneTheFollowingDayForTheSameLength() throws {
        let w = try AnchorWorld()
        _ = plants(w)
        _ = try sync(w, day: 5)
        // The window closed at the end of the 9th and nobody tapped: still stored as pending.
        let report = try sync(w, day: 10)
        #expect(report.created == 1)
        let next = try #require(try w.anchors().last)
        #expect(next.windowStart == start(w, 10))                       // the day after the last open day
        #expect(next.windowEnd == start(w, 12))                         // open for the same two days, not pushed 3 days out
    }

    @Test func aMissedAnchorAlreadyStoredAsMissedBehavesTheSame() throws {
        let w = try AnchorWorld()
        _ = plants(w)
        _ = try sync(w, day: 5)
        let first = try #require(try w.anchors().first)
        first.status = .missed
        first.resolvedAt = first.windowEnd
        _ = try sync(w, day: 10)
        #expect(try w.anchors().last?.windowStart == start(w, 10))
    }

    // MARK: Exceptions pause the clock

    @Test func noWindowOpensInsideAnExceptionAndTheNextOpensWhenItEnds() throws {
        let w = try AnchorWorld()
        _ = plants(w, exceptions: [AnchorException(from: w.d(7), to: w.d(10), reason: "travel")])
        _ = try sync(w, day: 5)
        let anchor = try #require(try w.anchors().first)
        #expect(anchor.windowStart == start(w, 11))                     // would have been the 8th
        #expect(anchor.windowEnd == start(w, 13))                       // same length
    }

    @Test func anOpenEndedExceptionGeneratesNothingUntilTheUserEndsIt() throws {
        let w = try AnchorWorld()
        let rule = plants(w, exceptions: [AnchorException(from: w.d(6), to: nil, reason: "illness")])
        _ = try sync(w, day: 5)
        #expect(try w.anchors().isEmpty)
        var config = ScheduledConfig(version: 1, recurrence: .afterLast(minDays: 3, maxDays: 4, startDate: w.d(5)),
                                     slots: [w.slot("water", "", "00:00", minutes: 1, allDay: true)],
                                     exceptions: [AnchorException(from: w.d(6), to: w.d(9), reason: "illness")])
        config.reminder = nil
        rule.configData = config.json                                    // the user ends it
        _ = try sync(w, day: 9)
        #expect(try w.anchors().first?.windowStart == start(w, 10))
    }

    @Test func addingAnExceptionOverALivePendingWindowRemovesItAndItReopensAfterwards() throws {
        let w = try AnchorWorld()
        let rule = plants(w)
        _ = try sync(w, day: 5)
        rule.configData = w.scheduled(.afterLast(minDays: 3, maxDays: 4, startDate: w.d(5)),
                                      slots: [w.slot("water", "", "00:00", minutes: 1, allDay: true)],
                                      exceptions: [AnchorException(from: w.d(8), to: w.d(9), reason: "holiday")]).json
        let report = try sync(w, day: 6)
        #expect(report.removed == 1)
        #expect(report.created == 1)
        #expect(try w.anchors().count == 1)
        #expect(try w.anchors().first?.windowStart == start(w, 10))
    }

    @Test func noWindowOpensAfterTheEndDate() throws {
        let w = try AnchorWorld()
        _ = plants(w, endDate: w.d(7))                                   // the first would open on the 8th
        _ = try sync(w, day: 5)
        #expect(try w.anchors().isEmpty)
    }

    // MARK: Lifecycle

    @Test func disablingOrArchivingRemovesTheLivePendingWindowButKeepsHistory() throws {
        let w = try AnchorWorld()
        let rule = plants(w)
        _ = try sync(w, day: 5)
        let first = try #require(try w.anchors().first)
        first.status = .attended
        first.resolvedAt = w.at(9, 10)
        _ = try sync(w, day: 9)
        #expect(try w.anchors().count == 2)
        rule.isEnabled = false
        _ = try sync(w, day: 9)
        #expect(try w.anchors().map(\.id) == [first.id])               // the pending window goes, the attended one stays
    }

    // MARK: Preview and free time

    @Test func previewShowsTheLiveOrProjectedWindowOnTheDaysItIsOpen() throws {
        let w = try AnchorWorld()
        let rule = plants(w)
        let days = (5...12).map { w.d($0) }
        let projected = AnchorGenerator.preview(rule: rule, days: days, boundary: w.boundary)
        #expect(projected.map(\.windowStart) == [start(w, 8)])           // projected, not stored yet
        #expect(AnchorGenerator.preview(rule: rule, days: [w.d(5), w.d(6)], boundary: w.boundary).isEmpty)   // not open on those days
        #expect(try w.anchors().isEmpty)                                 // a preview never writes
    }

    @Test func anAfterLastAnchorIsFlexibleSoItOnlyReducesFreeTime() throws {
        let w = try AnchorWorld()
        let rule = plants(w)
        _ = try sync(w, day: 5)
        let anchor = try #require(try w.anchors().first)
        #expect(rule.placement == "fixed")                               // the rule's own placement is ignored for afterLast
        let commitments = FreeTime.commitments(from: [anchor])
        #expect(commitments.first?.isFixed == false)
    }
}
