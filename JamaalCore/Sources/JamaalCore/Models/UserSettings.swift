import Foundation
import SwiftData

/// The single synced settings row. See docs/architecture/rules-engine.md.
@Model
public final class UserSettings {
    public var id: UUID = UUID()
    public var mediumDayMinutes: Int = 180
    public var dayStartMinute: Int = 480
    public var dayEndMinute: Int = 1140
    public var rolloverMinute: Int = 0
    public var weekdayLevels: String = #"{"6":"low","7":"low"}"#
    public var planningMinute: Int = 1200
    public var morningMinute: Int = 480
    public var onboardingCompletedAt: Date? = nil
    public var firstLaunchAt: Date? = nil
    public var createdAt: Date = Date.now

    public init() {
    }
}
