//
//  PrivacyCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The words around privacy, export and deletion: plain and complete.
enum PrivacyCopy {
    static let statement = "Everything you add is kept on your devices and in your own iCloud. Jamaal has no account and no server, and nothing is shared or sold."
    static let exportNote = "A JSON file of everything. Always available, subscribed or not."
    static let deleteNote = "Removes it from this device and iCloud, after two confirmations."

    static func fileName(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "Jamaal-export-%04d-%02d-%02d.json", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func exported(records: Int) -> String { "Exported \(records) \(records == 1 ? "record" : "records"). Choose where to keep the file." }
    static let deleted = "Everything was deleted. Jamaal starts again from the beginning."

    static let firstTitle = "Delete all your data?"
    static let firstMessage = "This removes everything from this device and iCloud. You can export it first."
    static let secondTitle = "Delete everything for good?"
    static let secondMessage = "This can't be undone. Your tasks, habits, Anchors and history will be gone."

    // The recovery screen (SY-05)
    static func recoveryTitle(device: String) -> String { "Jamaal couldn't open its data on this \(device)." }
    static func recoveryBody(device: String) -> String { "Trying again usually works. If it doesn't, you can reset this \(device)'s copy — your iCloud copy downloads again afterwards." }
    static func recoveryStillFailing(device: String) -> String { "It still won't open. Try once more, or reset this \(device)'s copy." }
    static func resetButton(device: String) -> String { "Reset this \(device)'s data" }
    static func resetFirstTitle(device: String) -> String { "Reset this \(device)'s data?" }
    static func resetFirstMessage(device: String) -> String { "This removes Jamaal's copy on this \(device). Your iCloud copy downloads again afterwards." }
    static let resetSecondTitle = "Reset now?"
    static func resetSecondMessage(device: String) -> String { "This can't be undone on this \(device)." }
}
