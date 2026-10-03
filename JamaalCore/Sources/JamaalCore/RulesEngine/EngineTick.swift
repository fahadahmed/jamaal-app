import Foundation
import SwiftData

/// What one tick changed.
public struct EngineTickResult {
    /// Settings or default categories had to be created (a first launch).
    public var seeded: Bool
    public var dedup: DedupReport
    public var rollover: RolloverReport
    /// Still-pending Anchors whose window had closed, now stored as missed.
    public var anchorsFinalised: Int
    public var anchors: AnchorSyncReport
    /// The most recent ended day now processed: keep it (per device) and pass it to the next tick.
    public var lastProcessed: CalendarDate
}

/// Everything the app keeps current on launch and whenever it becomes active, as one **idempotent**
/// call: a second tick over the same moment changes nothing.
///
/// In order: seed what is missing (settings, the default categories), merge duplicates another device
/// created, catch up every day that has ended since the last tick (auto-deferral, the day's record,
/// timers closed at the boundary, unfinished planning ended), generate Anchors for today and tomorrow,
/// then store *missed* for Anchor windows that have closed. The rollover runs on the user's own
/// rollover time, read after seeding.
public enum EngineTick {

    @MainActor
    @discardableResult
    public static func run(
        in context: ModelContext, now: Date, timeZone: TimeZone = .current, lastProcessed: CalendarDate?
    ) throws -> EngineTickResult {
        let seeded = try Seeding.ensureSeeded(in: context, now: now)
        let dedup = try Dedup.run(in: context, now: now)

        let settings = try context.fetch(FetchDescriptor<UserSettings>())
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) } ?? UserSettings()
        let boundary = DayBoundary(rolloverMinute: settings.rolloverMinute, timeZone: timeZone)

        let rollover = try Rollover.catchUp(in: context, boundary: boundary, lastProcessed: lastProcessed, now: now)
        let anchors = try AnchorGenerator.sync(in: context, boundary: boundary, now: now)
        let finalised = try AnchorAttendance.finalizeClosed(in: context, at: now)

        return EngineTickResult(
            seeded: seeded, dedup: dedup, rollover: rollover,
            anchorsFinalised: finalised, anchors: anchors, lastProcessed: rollover.lastProcessed
        )
    }
}
