import Foundation
import SwiftData

/// How far through its window an Anchor is. Derived from the clock, never stored.
public enum AnchorWindowState: Sendable, Hashable {
    case upcoming, open, closingSoon, closed
}

/// Window states and the logging rules (docs/schema/anchor.md, "Window state and logging rules").
public enum AnchorAttendance {

    public enum LogError: Error, Equatable, Sendable {
        /// `attended` can't be logged before the window opens.
        case notOpenYet
        /// The window has closed.
        case windowClosed
        /// Only a missed Anchor can be marked done after all.
        case notMissed
        /// The end of that logical day has passed.
        case pastDeadline
    }

    /// The last 25% of a window, and never less than 10 minutes, is `closingSoon` (tunable).
    static let closingSoonFraction = 0.25
    static let closingSoonMinimum: TimeInterval = 10 * 60

    public static func windowState(of anchor: Anchor, at now: Date) -> AnchorWindowState {
        if now < anchor.windowStart { return .upcoming }
        if now >= anchor.windowEnd { return .closed }
        let length = anchor.windowEnd.timeIntervalSince(anchor.windowStart)
        let threshold = max(length * closingSoonFraction, closingSoonMinimum)
        return anchor.windowEnd.timeIntervalSince(now) <= threshold ? .closingSoon : .open
    }

    /// The status to show: a still-pending Anchor whose window has closed reads as missed at once,
    /// before the stored status is finalised.
    public static func displayStatus(of anchor: Anchor, at now: Date) -> AttendanceStatus {
        anchor.status == .pending && windowState(of: anchor, at: now) == .closed ? .missed : anchor.status
    }

    // MARK: Logging

    /// `attended` only while the window is open or closing soon.
    public static func attend(_ anchor: Anchor, at now: Date) throws {
        switch windowState(of: anchor, at: now) {
        case .upcoming: throw LogError.notOpenYet
        case .closed: throw LogError.windowClosed
        case .open, .closingSoon: resolve(anchor, .attended, now)
        }
    }

    /// "Not today": any time before the window closes, including while upcoming. Not a miss.
    public static func skip(_ anchor: Anchor, at now: Date) throws {
        guard windowState(of: anchor, at: now) != .closed else { throw LogError.windowClosed }
        resolve(anchor, .skipped, now)
    }

    /// "Someone else did it": any time before the window closes. Handled, not a miss.
    public static func delegate(_ anchor: Anchor, at now: Date) throws {
        guard windowState(of: anchor, at: now) != .closed else { throw LogError.windowClosed }
        resolve(anchor, .delegated, now)
    }

    /// A missed Anchor can be marked done after all until the end of the logical day its window
    /// closed (the day containing the instant it closed, so a window that closes at midnight is
    /// correctable through the day that follows). It never reopens a skipped or delegated one, and never an open window.
    public static func markDoneAfterAll(_ anchor: Anchor, at now: Date, boundary: DayBoundary) throws {
        guard displayStatus(of: anchor, at: now) == .missed else { throw LogError.notMissed }
        let closeDay = boundary.logicalDate(at: anchor.windowEnd)
        guard boundary.logicalDate(at: now) == closeDay else { throw LogError.pastDeadline }
        resolve(anchor, .attended, now)
    }

    /// A quiet undo of an accidental tap, while the window is still open.
    public static func undo(_ anchor: Anchor, at now: Date) throws {
        guard anchor.status == .attended || anchor.status == .skipped || anchor.status == .delegated else { return }
        guard windowState(of: anchor, at: now) != .closed else { throw LogError.windowClosed }
        anchor.status = .pending
        anchor.resolvedAt = nil
    }

    /// Stores `missed` for every still-pending Anchor whose window has closed, at its window's end.
    /// Idempotent; returns how many it changed.
    @MainActor
    @discardableResult
    public static func finalizeClosed(in context: ModelContext, at now: Date) throws -> Int {
        var count = 0
        for anchor in try context.fetch(FetchDescriptor<Anchor>()) where anchor.status == .pending && anchor.windowEnd <= now {
            anchor.status = .missed
            anchor.resolvedAt = anchor.windowEnd
            count += 1
        }
        if count > 0 { try context.save() }
        return count
    }

    private static func resolve(_ anchor: Anchor, _ status: AttendanceStatus, _ now: Date) {
        anchor.status = status
        anchor.resolvedAt = now
    }
}
