//
//  OnboardingCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// Onboarding's words. Calm and short; nothing promises more than the app does (it suggests, it doesn't learn silently).
enum OnboardingCopy {
    static let hello = "Hello. I'm Jamaal."
    static let helloBody = "One list, just for today. I'll help you choose what belongs on it, and notice when it's too much."

    static let ideaTitle = "One list. Just today."
    static let ideaAccent = "Three ways in."
    static let ideaRows: [(title: String, detail: String)] = [
        ("Tasks you do", "Ticked off when they're done"),
        ("Habits you grow", "Read by how often, never by streaks"),
        ("Anchors you move around", "Prayer times, the school run, bin night"),
    ]
    static let notHere = "Projects and boards · Streaks and guilt"
    static let iCloudLine = "Kept in your own iCloud."

    static let iCloudTitle = "iCloud isn't on"
    static let iCloudBody = "Jamaal works without iCloud; your data just won't sync until you sign in."

    static let dayTitle = "How much fits in a normal day?"
    static let daySubtitle = "Time for tasks, not counting prayers, the school run or habits. A rough guess is fine; I can suggest a better number once I've seen a few weeks."
    static let dayEnds = "My working day ends at"
    static let todayFeels = "And today feels"

    static let speakTitle = "When should I speak?"
    static let speakBody = "Once at night to plan, once in the morning with your list. Anything else is yours to switch on."

    static let taskEyebrow = "FIRST, A TASK"
    static let taskTitle = "Something you need to do today."
    static let taskPlaceholder = "What is it?"
    static let labelEyebrow = "A LABEL, IF YOU LIKE"
    static let labelNote = "Labels, not folders. Today stays one list."

    static let habitEyebrow = "THEN, A HABIT"
    static let habitTitle = "Something you'd like to do more often."

    static let anchorEyebrow = "AND SOMETHING FIXED"
    static let anchorTitle = "What does your day move around?"
    static let anchorBody = "Jamaal plans tasks into the time between these, and never moves them."

    static let readyTitle = "Tonight, we'll plan tomorrow."
    static let trial = "14 days free. Nothing to pay now."

    /// "Until then, today has one task and one habit." from what was actually made.
    static func readyBody(tasks: Int, habits: Int, anchors: Int) -> String {
        func part(_ n: Int, _ one: String, _ many: String) -> String? { n == 0 ? nil : n == 1 ? "one \(one)" : "\(n) \(many)" }
        let items = [part(tasks, "task", "tasks"), part(habits, "habit", "habits"), part(anchors, "Anchor", "Anchors")].compactMap { $0 }
        guard !items.isEmpty else { return "Until then, today is yours." }
        let joined: String
        switch items.count {
        case 1: joined = items[0]
        case 2: joined = "\(items[0]) and \(items[1])"
        default: joined = items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
        return "Until then, today has \(joined)."
    }

    /// The day-zero card on Today.
    static func tonightLine(planningMinute: Int) -> String {
        "At \(PlanningCopy.clock(planningMinute)) I'll ask how today went, and we'll set up tomorrow together."
    }
    static let tonightTitle = "Tonight, we'll plan tomorrow."

    static func addHabitButton(_ title: String) -> String { "Add \(title)" }

    static func message(for error: Error) -> String {
        switch error {
        case TaskCreationError.emptyTitle: return "Give it a name first."
        case HabitEditError.emptyTitle: return "Give it a name first."
        case let error as SettingsError: return SettingsCopy.message(for: error)
        default: return "That couldn't be saved. Try again."
        }
    }
}
