import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Window states and the logging rules (docs/schema/anchor.md, "Window state and logging rules").
@MainActor
struct AnchorAttendanceTests {

    // A one-hour window, 10:00–11:00 on Monday 5 October.
    private func make(_ w: AnchorWorld, minutes: Int = 60, status: AttendanceStatus = .pending) -> Anchor {
        w.anchor("Asr", from: w.at(5, 10), minutes: minutes, status: status)
    }

    // MARK: States

    @Test(arguments: [
        ((9, 59), AnchorWindowState.upcoming), ((10, 0), .open), ((10, 44), .open),
        ((10, 45), .closingSoon), ((10, 59), .closingSoon), ((11, 0), .closed), ((14, 0), .closed),
    ])
    func theLastQuarterOfTheWindowIsClosingSoon(time: (Int, Int), expected: AnchorWindowState) throws {
        let w = try AnchorWorld()
        let a = make(w)
        #expect(AnchorAttendance.windowState(of: a, at: w.at(5, time.0, time.1)) == expected)
    }

    @Test func aShortWindowIsClosingSoonForItsLastTenMinutesAtLeast() throws {
        let w = try AnchorWorld()
        let a = make(w, minutes: 20)                                      // 25% would be 5 minutes; the floor is 10
        #expect(AnchorAttendance.windowState(of: a, at: w.at(5, 10, 9)) == .open)
        #expect(AnchorAttendance.windowState(of: a, at: w.at(5, 10, 10)) == .closingSoon)
    }

    @Test func aPendingAnchorWhoseWindowClosedReadsAsMissedAtOnce() throws {
        let w = try AnchorWorld()
        let a = make(w)
        #expect(AnchorAttendance.displayStatus(of: a, at: w.at(5, 10, 30)) == .pending)
        #expect(AnchorAttendance.displayStatus(of: a, at: w.at(5, 11)) == .missed)
        a.status = .skipped
        #expect(AnchorAttendance.displayStatus(of: a, at: w.at(5, 11)) == .skipped)
    }

    // MARK: Logging

    @Test func attendedOnlyWhileTheWindowIsOpen() throws {
        let w = try AnchorWorld()
        let a = make(w)
        #expect(throws: AnchorAttendance.LogError.notOpenYet) { try AnchorAttendance.attend(a, at: w.at(5, 9, 30)) }
        #expect(a.status == .pending)
        try AnchorAttendance.attend(a, at: w.at(5, 10, 52))
        #expect(a.status == .attended)
        #expect(a.resolvedAt == w.at(5, 10, 52))
        let late = make(w)
        #expect(throws: AnchorAttendance.LogError.windowClosed) { try AnchorAttendance.attend(late, at: w.at(5, 11, 1)) }
    }

    @Test func skippedOrDelegatedAnyTimeBeforeTheWindowCloses() throws {
        let w = try AnchorWorld()
        let upcoming = make(w), open = make(w), closed = make(w)
        try AnchorAttendance.skip(upcoming, at: w.at(5, 8))
        try AnchorAttendance.delegate(open, at: w.at(5, 10, 20))
        #expect(upcoming.status == .skipped)
        #expect(open.status == .delegated)
        #expect(open.resolvedAt == w.at(5, 10, 20))
        #expect(throws: AnchorAttendance.LogError.windowClosed) { try AnchorAttendance.skip(closed, at: w.at(5, 11)) }
        #expect(throws: AnchorAttendance.LogError.windowClosed) { try AnchorAttendance.delegate(closed, at: w.at(5, 12)) }
    }

    @Test func aMissedAnchorCanBeMarkedDoneAfterAllUntilTheEndOfThatLogicalDay() throws {
        let w = try AnchorWorld()
        let a = make(w)
        try AnchorAttendance.markDoneAfterAll(a, at: w.at(5, 20), boundary: w.boundary)          // pending but closed: reads as missed
        #expect(a.status == .attended)
        #expect(a.resolvedAt == w.at(5, 20))

        let stored = make(w, status: .missed)
        #expect(throws: AnchorAttendance.LogError.pastDeadline) { try AnchorAttendance.markDoneAfterAll(stored, at: w.at(6, 0, 1), boundary: w.boundary) }
        #expect(stored.status == .missed)
    }

    @Test func lateCorrectionNeverReopensSkippedOrDelegatedOrAnOpenWindow() throws {
        let w = try AnchorWorld()
        let skipped = make(w, status: .skipped), delegated = make(w, status: .delegated), open = make(w)
        #expect(throws: AnchorAttendance.LogError.notMissed) { try AnchorAttendance.markDoneAfterAll(skipped, at: w.at(5, 20), boundary: w.boundary) }
        #expect(throws: AnchorAttendance.LogError.notMissed) { try AnchorAttendance.markDoneAfterAll(delegated, at: w.at(5, 20), boundary: w.boundary) }
        #expect(throws: AnchorAttendance.LogError.notMissed) { try AnchorAttendance.markDoneAfterAll(open, at: w.at(5, 10, 30), boundary: w.boundary) }
    }

    @Test func anAnchorClosingAfterMidnightIsCorrectableThroughTheDayItClosed() throws {
        let w = try AnchorWorld()
        let isha = w.anchor("Isha", from: w.at(5, 22), minutes: 180, status: .missed)               // closes 01:00 on the 6th
        try AnchorAttendance.markDoneAfterAll(isha, at: w.at(6, 18), boundary: w.boundary)
        #expect(isha.status == .attended)
    }

    @Test func aWindowClosingAtMidnightIsCorrectableThroughTheDayThatFollows() throws {
        let w = try AnchorWorld()
        let plants = w.anchor("Water the plants", from: w.at(5, 0), minutes: 24 * 60, status: .missed)      // closes 00:00 on the 6th
        try AnchorAttendance.markDoneAfterAll(plants, at: w.at(6, 1), boundary: w.boundary)
        #expect(plants.status == .attended)
        let later = w.anchor("Again", from: w.at(5, 0), minutes: 24 * 60, status: .missed)
        #expect(throws: AnchorAttendance.LogError.pastDeadline) { try AnchorAttendance.markDoneAfterAll(later, at: w.at(7, 0, 1), boundary: w.boundary) }
    }

    @Test func aQuietUndoWorksOnlyWhileTheWindowIsStillOpen() throws {
        let w = try AnchorWorld()
        let a = make(w)
        try AnchorAttendance.attend(a, at: w.at(5, 10, 10))
        try AnchorAttendance.undo(a, at: w.at(5, 10, 12))
        #expect(a.status == .pending)
        #expect(a.resolvedAt == nil)
        try AnchorAttendance.attend(a, at: w.at(5, 10, 20))
        #expect(throws: AnchorAttendance.LogError.windowClosed) { try AnchorAttendance.undo(a, at: w.at(5, 11, 5)) }
        #expect(a.status == .attended)
    }

    // MARK: Closing windows

    @Test func finalisingStoresMissedForClosedPendingAnchorsAtTheirWindowEnd() throws {
        let w = try AnchorWorld()
        let closedPending = make(w)
        let stillOpen = w.anchor("Open", from: w.at(5, 13), minutes: 60)
        let skipped = make(w, status: .skipped)
        let count = try AnchorAttendance.finalizeClosed(in: w.context, at: w.at(5, 12))
        #expect(count == 1)                                                // only the closed, still-pending one
        #expect(closedPending.status == .missed)
        #expect(closedPending.resolvedAt == w.at(5, 11))
        #expect(stillOpen.status == .pending)
        #expect(skipped.status == .skipped)
        #expect(try AnchorAttendance.finalizeClosed(in: w.context, at: w.at(5, 12)) == 0)       // idempotent
    }
}
