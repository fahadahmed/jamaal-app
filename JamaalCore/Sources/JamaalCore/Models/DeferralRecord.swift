import Foundation
import SwiftData

/// One deferral of a task to a later day. See docs/schema/task.md, "Deferral behaviour".
@Model
public final class DeferralRecord {
    public var id: UUID = UUID()
    public var deferredOn: Date = Date.now
    public var day: Date = Date.now
    public var deferredTo: Date? = nil
    public var reason: String = "unspecified"

    public var task: TaskItem?

    public init() {
    }

    /// Typed view of `reason`; reads an unrecognised value as `.unknown` and never writes it back.
    public var reasonKind: DeferralReason {
        get { DeferralReason(stored: reason) }
        set { if let raw = newValue.storable { reason = raw } }
    }
}
