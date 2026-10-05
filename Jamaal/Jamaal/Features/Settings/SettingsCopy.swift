//
//  SettingsCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The Settings tab's words.
enum SettingsCopy {
    static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// "3h · 08:00–19:00" on the home row.
    static func capacitySummary(_ settings: UserSettings) -> String {
        "\(TodayCopy.duration(settings.mediumDayMinutes)) · \(PlanningCopy.clock(settings.dayStartMinute))–\(PlanningCopy.clock(settings.dayEndMinute))"
    }

    /// "Low is 2h, high is 4h."
    static func levels(mediumDayMinutes: Int) -> String {
        let low = CapacityLoad.budgetMinutes(for: .low, mediumDayMinutes: mediumDayMinutes)
        let high = CapacityLoad.budgetMinutes(for: .high, mediumDayMinutes: mediumDayMinutes)
        return "Low is \(TodayCopy.duration(low)), high is \(TodayCopy.duration(high))."
    }

    /// "You usually do about 2h 40m — set your normal day to that?"
    static func suggestion(_ minutes: Int) -> String {
        "You usually do about \(TodayCopy.duration(minutes)) — set your normal day to that?"
    }

    /// The quiet note when planning comes before the working day ends (G-57).
    static func planningNote(planningMinute: Int) -> String {
        "Planning is at \(PlanningCopy.clock(planningMinute)), before the working day ends. That's fine; tonight's review will show the day so far."
    }

    /// Under "A new day starts at": what can be done now.
    static func rolloverNote(_ availability: RolloverAvailability) -> String {
        switch availability {
        case .upTo: "Takes effect from the next day."
        case .after(let minute): "Can change after \(PlanningCopy.clock(minute)) today"
        }
    }

    /// The rollover options: every half hour from 00:00 to 06:00, each with whether it can be chosen now.
    static func rolloverOptions(_ availability: RolloverAvailability) -> [(minute: Int, enabled: Bool)] {
        let limit: Int
        switch availability {
        case .upTo(let minute): limit = minute
        case .after: limit = -1
        }
        return stride(from: 0, through: DaySettings.rolloverRange.upperBound, by: 30).map { ($0, $0 <= limit) }
    }

    static func message(for error: SettingsError) -> String {
        switch error {
        case .normalDayOutOfRange: "A normal day is between 30 minutes and 6 hours."
        case .workingDayInvalid: "The working day needs at least two hours, and to start after the new day does."
        case .rolloverOutOfRange: "The new day can start between midnight and 06:00."
        case .rolloverNotChangeableNow: "That can't change right now. Try once that time has passed today."
        case .emptyName: "Give it a name first."
        case .nameTooLong: "Keep it to 24 characters."
        case .nameTaken: "You already have a label with that name."
        case .tooManyCategories: "Eight is plenty: fewer, broader labels work better. Archive one to add another."
        case .notFound: "That label couldn't be found."
        }
    }

    /// The minute of the day at `date` in `timeZone`.
    static func minuteOfDay(_ date: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func categoriesSubtitle(active: Int) -> String { "Labels for tasks. \(active) of \(CategoryEditing.activeLimit) in use." }
}
