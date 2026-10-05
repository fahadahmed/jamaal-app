//
//  WellbeingCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// Wellbeing's words: plain, unjudged, in Jamaal's voice. No praise, no blame, no coloured scores.
enum WellbeingCopy {

    /// "About the same as two weeks ago": the score against the fortnight before it.
    static func trend(_ trend: WellbeingTrend?) -> String? {
        switch trend {
        case .steadier: "Steadier than two weeks ago"
        case .aboutTheSame: "About the same as two weeks ago"
        case .heavier: "Heavier than two weeks ago"
        case nil: nil
        }
    }

    private static let numbers = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
    private static func count(_ n: Int) -> String { n < numbers.count ? numbers[n] : "\(n)" }

    /// The sentence under the score. A pattern that is active leads; otherwise the day-to-day read.
    static func read(_ snapshot: WellbeingSnapshot, patterns: [WellbeingPattern]) -> String {
        switch patterns.first?.kind {
        case .heavyRun: return "The last three days were each over their budget."
        case .completionCollapse: return "Fewer tasks have been finished over the last few days than usual."
        case .weekendOverplan: return "The last few weekends ran over their budget."
        case .habitNeglect: return "A habit has been slipping for a few days."
        case nil: break
        }
        var phrases: [String] = []
        if let tasks = snapshot.parts.first(where: { $0.kind == .tasks }) {
            phrases.append(tasks.value >= 70 ? "Most tasks got done" : tasks.value >= 40 ? "Some tasks got done" : "Fewer tasks got done")
        }
        if snapshot.anchorsDecided > 0, let anchors = snapshot.parts.first(where: { $0.kind == .anchors }) {
            phrases.append(anchors.value >= 80 ? "the Anchors held" : "some Anchors slipped by")
        }
        switch snapshot.heavyDays {
        case 0: phrases.append("no day ran heavy")
        case 1: phrases.append("one day ran heavy")
        case let n where n * 5 <= snapshot.activeDays: phrases.append("only \(count(n)) days ran heavy")
        case let n: phrases.append("\(count(n)) days ran heavy")
        }
        return sentence(phrases)
    }

    private static func sentence(_ phrases: [String]) -> String {
        guard let first = phrases.first else { return "" }
        let joined: String
        switch phrases.count {
        case 1: joined = first
        case 2: joined = "\(first) and \(phrases[1])"
        default: joined = phrases.dropLast().joined(separator: ", ") + ", and " + phrases.last!
        }
        return joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }

    /// A word for how habits have gone, never a figure.
    static func habits(_ value: Double) -> String { value >= 75 ? "Most days" : value >= 40 ? "Some days" : "Fewer days" }

    struct Row: Equatable { var title: String; var value: String; var id: String }

    /// The rows under the read; a row appears only when there is something behind it.
    static func rows(_ snapshot: WellbeingSnapshot) -> [Row] {
        var rows: [Row] = []
        if snapshot.tasksToFinish > 0 { rows.append(Row(title: "Tasks done", value: "\(snapshot.tasksDone) of \(snapshot.tasksToFinish)", id: "tasks")) }
        if snapshot.anchorsDecided > 0 { rows.append(Row(title: "Anchors attended", value: "\(snapshot.anchorsAttended) of \(snapshot.anchorsDecided)", id: "anchors")) }
        if let habits = snapshot.parts.first(where: { $0.kind == .habits }) { rows.append(Row(title: "Habits", value: Self.habits(habits.value), id: "habits")) }
        rows.append(Row(title: "Heavy days", value: "\(snapshot.heavyDays) of \(snapshot.activeDays)", id: "heavy"))
        return rows
    }

    // MARK: Gathering data

    static func gathering(activeDays: Int, needed: Int) -> String { "\(min(activeDays, needed)) of \(needed) days" }
    static let gatheringLine = "A reading appears after seven active days."
    static let willRead: [(title: String, source: String)] = [
        ("Tasks done", "from what you tick off"), ("Anchors attended", "from what you mark"),
        ("Habits", "from what you log"), ("Load", "from each day's budget"),
    ]
    static let nothingToFillIn = "Nothing to fill in. It comes only from what you already do."

    // MARK: The card

    private static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    static func cardText(_ pattern: WellbeingPattern) -> String {
        switch pattern.kind {
        case .heavyRun: "The last three days were heavy. Make tomorrow a low day?"
        case .weekendOverplan:
            "\(day(pattern.weekday))s have run over lately. Make \(day(pattern.weekday)) a low day?"
        case .completionCollapse: "Fewer tasks have fit lately. Lower your normal day to match?"
        case .habitNeglect: "\(pattern.habit?.title ?? "A habit") has slipped a few days. Pause it, or make it smaller?"
        }
    }

    static func cardAction(_ pattern: WellbeingPattern) -> String {
        switch pattern.kind {
        case .heavyRun: "Lower tomorrow"
        case .weekendOverplan: "Lighten \(day(pattern.weekday))"
        case .completionCollapse: "Lower my normal day"
        case .habitNeglect: "Look at it"
        }
    }

    private static func day(_ weekday: Int?) -> String {
        guard let weekday, (1...7).contains(weekday) else { return "Saturday" }
        return weekdayNames[weekday - 1]
    }

    /// The quiet line that replaces the card once its action is taken.
    static func outcome(_ outcome: WellbeingActionOutcome) -> String? {
        switch outcome {
        case .capacityLowered: "Tomorrow is a low day."
        case .weekdayLowered(let weekday): "\(day(weekday))s are low days now."
        case .normalDayChanged(let minutes): "Your normal day is now \(TodayCopy.duration(minutes))."
        case .openHabit, .nothing: nil
        }
    }

    /// The Today strip when there is not yet a reading.
    static func strip(gathering activeDays: Int, needed: Int) -> String { "Wellbeing · gathering data · \(min(activeDays, needed)) of \(needed)" }
}
