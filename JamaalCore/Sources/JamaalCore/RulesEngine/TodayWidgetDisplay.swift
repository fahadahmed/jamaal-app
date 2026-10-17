import Foundation

/// What the Today widget says, in each of its sizes (frame WG-03). Built from a `WidgetSnapshot`, so it can only say what Today would.
public struct TodayWidgetDisplay: Equatable, Sendable {

    public enum Mood: Equatable, Sendable {
        /// Tasks to do, before the planning time.
        case normal
        /// Tasks left, from the planning time: "then rest".
        case evening
        /// Everything planned is done.
        case allDone
        /// Nothing planned and nothing done.
        case blank
    }

    public struct Headline: Equatable, Sendable {
        public var first: String
        /// Set in the italic accent.
        public var second: String
        public init(first: String, second: String) { self.first = first; self.second = second }
    }

    public var mood: Mood
    public var eyebrow: String
    public var headline: Headline
    public var tasksLeft: Int
    public var capacityText: String
    public var stateWord: String
    public var isOver: Bool
    /// 0…1, never past full.
    public var barFill: Double
    /// The bar steps aside on an all-done day and a blank one.
    public var showsCapacity: Bool
    /// "4 of 4 done", on an all-done day.
    public var doneLine: String?
    public var mediumTasks: [WidgetSnapshot.TaskLine]
    public var mediumMore: String?
    public var largeTasks: [WidgetSnapshot.TaskLine]
    public var largeMore: String?
    public var anchor: NextAnchorDisplay
    public var anchorBar: NextAnchorCopy.Bar?
    /// The terracotta pill that opens Night Planning: from the planning time, on the medium and large only, never when read-only.
    public var showsPlanTomorrow: Bool
    /// The one quiet note when the trial has ended: no upgrade prompt on a widget.
    public var viewOnly: Bool
}

public extension WidgetSnapshot {
    var todayWidgetDisplay: TodayWidgetDisplay {
        let mood: TodayWidgetDisplay.Mood =
            tasksLeft == 0 ? (tasksDone > 0 ? .allDone : .blank) : (planningDue ? .evening : .normal)
        let anchor = nextAnchorDisplay
        let fill = capacity.budgetMinutes > 0 ? min(1, max(0, Double(capacity.plannedMinutes) / Double(capacity.budgetMinutes))) : 0
        return TodayWidgetDisplay(
            mood: mood,
            eyebrow: TodayWidgetCopy.eyebrow(mood),
            headline: TodayWidgetCopy.headline(mood, remaining: tasksLeft),
            tasksLeft: tasksLeft,
            capacityText: "\(TodayWidgetCopy.duration(capacity.plannedMinutes)) of \(TodayWidgetCopy.duration(capacity.budgetMinutes))",
            stateWord: TodayWidgetCopy.stateWord(capacity.state),
            isOver: capacity.state == .overloaded || capacity.state == .exhausting,
            barFill: fill,
            showsCapacity: mood == .normal || mood == .evening,
            doneLine: mood == .allDone ? "\(tasksDone) of \(tasksDone) done" : nil,
            mediumTasks: Array(tasks.prefix(2)),
            mediumMore: TodayWidgetCopy.more(tasksLeft - 2, noun: false),
            largeTasks: Array(tasks.prefix(5)),
            largeMore: TodayWidgetCopy.more(tasksLeft - 5, noun: true),
            anchor: anchor,
            anchorBar: NextAnchorCopy.bar(anchor),
            showsPlanTomorrow: showsPlanTomorrow,
            viewOnly: isReadOnly)
    }
}

/// The Today widget's words, in Jamaal's voice, matching what Today says.
public enum TodayWidgetCopy {

    public static func eyebrow(_ mood: TodayWidgetDisplay.Mood) -> String { mood == .evening ? "This evening" : "Today" }

    public static func headline(_ mood: TodayWidgetDisplay.Mood, remaining: Int) -> TodayWidgetDisplay.Headline {
        switch mood {
        case .normal: .init(first: "\(countWord(remaining)) \(remaining == 1 ? "thing" : "things"),", second: "gently paced.")
        case .evening: .init(first: "\(countWord(remaining)) \(remaining == 1 ? "thing" : "things") left,", second: "then rest.")
        case .allDone: .init(first: "All done.", second: "The rest is yours.")
        case .blank: .init(first: "Nothing planned.", second: "An open day.")
        }
    }

    /// "One" … "Ten", then digits, as Today does.
    public static func countWord(_ n: Int) -> String { n >= 0 && n < numberWords.count ? numberWords[n] : "\(n)" }
    private static let numberWords = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]

    /// "2h 15m", "3h", "45m".
    public static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }

    public static func stateWord(_ state: LoadState) -> String {
        switch state {
        case .light: "LIGHT"
        case .balanced: "BALANCED"
        case .full: "FULL"
        case .overloaded, .exhausting: "OVER"
        }
    }

    /// "60 min", or nothing when there is no estimate.
    public static func effort(_ minutes: Int?) -> String? { minutes.flatMap { $0 > 0 ? "\($0) min" : nil } }

    /// "and 2 more" (medium) or "and 1 more task" (large); nothing when there are none.
    public static func more(_ count: Int, noun: Bool) -> String? {
        guard count > 0 else { return nil }
        return noun ? "and \(count) more \(count == 1 ? "task" : "tasks")" : "and \(count) more"
    }

    /// "Dhuhr · until 15:32", "Isha · from 19:48"; nothing when no Anchor is left.
    public static func anchorLine(_ display: NextAnchorDisplay, time: (Date) -> String) -> String? {
        switch display {
        case .open(let w), .closingSoon(let w): "\(w.name) · until \(time(w.end))"
        case .upcoming(let w): "\(w.name) · from \(time(w.start))"
        case .needsAttention(let w): "\(w.name) · not marked yet"
        case .noneLeft: nil
        }
    }
}
