//
//  ReminderCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words around reminders and their permission.
enum ReminderCopy {

    /// The Settings home row's value.
    static func homeValue(switchOn: Bool, permission: NotificationPermission, device: String) -> String {
        guard switchOn else { return "Off on this \(device)" }
        switch permission {
        case .granted: return "On"
        case .notAsked: return "Not turned on yet"
        case .denied: return "Off in Settings"
        }
    }

    /// The warning card's first line.
    static func warningTitle(permission: NotificationPermission, device: String) -> String {
        permission == .notAsked
            ? "Jamaal hasn't been allowed to send notifications on this \(device) yet, so these won't arrive:"
            : "Notifications are off for Jamaal on this \(device), so these won't arrive:"
    }

    static func warningButton(_ permission: NotificationPermission, device: String) -> String {
        permission == .notAsked ? "Turn on reminders" : "Open \(device) Settings"
    }

    /// The quiet line under a configured reminder.
    static let quietLine = "Notifications are off, so this reminder won't arrive."

    /// "Set per habit" with what is true now.
    static func habitRow(blocked: Bool) -> String { blocked ? "Set per habit · notifications are off" : "Set on each habit's form" }

    static let banner = "Reminders are off, so there's no evening prompt."
    static let footer = "Times are shared across your devices. Whether a device sends reminders is set on each one."
}
