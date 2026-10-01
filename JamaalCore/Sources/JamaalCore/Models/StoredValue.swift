import Foundation

/// A raw-string value stored in a synced model.
///
/// An older app may read a raw value a newer app wrote (docs/schema/overview.md, "Raw values").
/// Every typed wrapper therefore has an inert `.unknown` case: a value the app doesn't
/// recognise reads as `.unknown`, and writing `.unknown` back never touches the stored
/// string, so the row is kept and never rewritten.
public protocol StoredValue: RawRepresentable, CaseIterable, Sendable, Hashable where RawValue == String {
    /// The case an unrecognised raw string maps to.
    static var unknownCase: Self { get }
}

extension StoredValue {
    /// Reads a stored string; anything unrecognised becomes `.unknown`.
    public init(stored: String) {
        self = Self(rawValue: stored) ?? Self.unknownCase
    }

    /// `true` for the inert fallback case.
    public var isUnknown: Bool { self == Self.unknownCase }

    /// The string to store, or `nil` for `.unknown` (which must never overwrite a stored value).
    public var storable: String? { isUnknown ? nil : rawValue }
}

public enum Importance: String, StoredValue {
    case low
    case medium
    case high
    case unknown
    public static var unknownCase: Importance { .unknown }
}

public enum RepeatKind: String, StoredValue {
    case off = "none"
    case daily
    case weekly
    case monthly
    case unknown
    public static var unknownCase: RepeatKind { .unknown }
}

public enum DeferralReason: String, StoredValue {
    case tooMuch
    case notReady
    case noLonger
    case reschedule
    case unspecified
    case unknown
    public static var unknownCase: DeferralReason { .unknown }
}

public enum SessionOutcome: String, StoredValue {
    case running
    case finished
    case deferred
    case dropped
    case abandoned
    case autoClosed
    case manual
    case unknown
    public static var unknownCase: SessionOutcome { .unknown }
}

public enum CategoryPreset: String, StoredValue {
    case personal
    case family
    case work
    case unknown
    public static var unknownCase: CategoryPreset { .unknown }
}

public enum CategoryColor: String, StoredValue {
    case accent
    case blue
    case ochre
    case plum
    case slate
    case unknown
    public static var unknownCase: CategoryColor { .unknown }
}

public enum HabitKind: String, StoredValue {
    case binary
    case counted
    case timed
    case avoid
    case unknown
    public static var unknownCase: HabitKind { .unknown }
}

public enum HabitFrequency: String, StoredValue {
    case daily
    case weekdays
    case custom
    case unknown
    public static var unknownCase: HabitFrequency { .unknown }
}

public enum HabitPreset: String, StoredValue {
    case quran
    case dhikr
    case exercise
    case running
    case unknown
    public static var unknownCase: HabitPreset { .unknown }
}

public enum AttendanceStatus: String, StoredValue {
    case pending
    case attended
    case missed
    case skipped
    case delegated
    case unknown
    public static var unknownCase: AttendanceStatus { .unknown }
}

public enum AnchorSource: String, StoredValue {
    case prayerWindow
    case schoolRun
    case binNight
    case plantWatering
    case custom
    case unknown
    public static var unknownCase: AnchorSource { .unknown }
}

public enum AnchorPlacement: String, StoredValue {
    case fixed
    case flexible
    case unknown
    public static var unknownCase: AnchorPlacement { .unknown }
}

public enum CapacityLevel: String, StoredValue {
    case low
    case medium
    case high
    case unknown
    public static var unknownCase: CapacityLevel { .unknown }
}

public enum PlanningStep: String, StoredValue {
    case review
    case carry
    case build
    case load
    case close
    case unknown
    public static var unknownCase: PlanningStep { .unknown }
}

public enum NudgeKind: String, StoredValue {
    case wellbeing
    case guidance
    case fatigue
    case windowClosing
    case overload
    case morningPlanCard
    case habitPromotion
    case normalDaySuggestion
    case unknown
    public static var unknownCase: NudgeKind { .unknown }
}

public enum PauseReason: String, StoredValue {
    case travel
    case illness
    case cycle
    case other
    case unknown
    public static var unknownCase: PauseReason { .unknown }
}
