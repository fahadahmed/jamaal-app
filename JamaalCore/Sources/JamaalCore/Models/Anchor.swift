import Foundation
import SwiftData

/// One window-bound instance of something your life moves around. See docs/schema/anchor.md.
@Model
public final class Anchor {
    public var id: UUID = UUID()
    public var title: String = ""
    public var occurrenceDate: Date = Date.now
    public var slotKey: String = ""
    public var windowStart: Date = Date.now
    public var windowEnd: Date = Date.now
    public var effortMinutes: Int? = nil
    public var attendanceStatus: String = "pending"
    public var resolvedAt: Date? = nil
    public var remindBeforeStartMinutes: Int? = nil
    public var remindBeforeEndMinutes: Int? = nil
    public var generatedAt: Date = Date.now

    public var rule: AnchorRule?

    public init(title: String = "") {
        self.title = title
    }

    /// Typed view of `attendanceStatus`; reads an unrecognised value as `.unknown` and never writes it back.
    public var status: AttendanceStatus {
        get { AttendanceStatus(stored: attendanceStatus) }
        set { if let raw = newValue.storable { attendanceStatus = raw } }
    }
}
