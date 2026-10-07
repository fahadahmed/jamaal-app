//
//  HabitMinutesCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words on the Add minutes sheet.
enum HabitMinutesCopy {

    /// "Qur'an reading · today, 6 of 15 min so far".
    static func subtitle(habit: String, day: CalendarDate, today: CalendarDate, done: Int, target: Int) -> String {
        "\(habit) · \(dayWord(day, today: today)), \(done) of \(target) min so far"
    }

    private static func dayWord(_ day: CalendarDate, today: CalendarDate) -> String {
        switch today.days(until: day) {
        case 0: "today"
        case -1: "yesterday"
        default: AddTaskForm.dateTitle(day)
        }
    }

    /// "Add 10 min".
    static func button(_ minutes: Int) -> String { "Add \(minutes) min" }

    /// "10 min · 09:12".
    static func sessionLine(minutes: Int, at date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return "\(minutes) min · " + String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    static func message(for error: HabitMinutesError) -> String {
        switch error {
        case .notATimedHabit: "Minutes are for habits measured in time."
        case .minutesOutOfRange: "Add between 1 minute and 12 hours."
        case .dayNotOpenForCorrection: "That day can't be changed: it's older than two weeks, before this habit began, or paused."
        }
    }
}
