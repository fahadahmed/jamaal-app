import Foundation
import SwiftData

/// A guidance, wellbeing or morning-card nudge shown, for the once-a-day checks.
@Model
public final class NudgeLog {
    public var id: UUID = UUID()
    public var kind: String = ""
    public var subjectKey: String? = nil
    public var sentAt: Date = Date.now
    public var dismissedAt: Date? = nil

    public init() {
    }

    /// Typed view of `kind`; reads an unrecognised value as `.unknown` and never writes it back.
    public var nudgeKind: NudgeKind {
        get { NudgeKind(stored: kind) }
        set { if let raw = newValue.storable { kind = raw } }
    }
}
