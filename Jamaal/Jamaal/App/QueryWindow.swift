//
//  QueryWindow.swift
//  Jamaal
//

import Foundation
import SwiftData
import JamaalCore

/// How far back the queries Today and the app shell **observe** look. Those queries are a change trigger, not the data: Today reads what it
/// shows through the model context, and only needs to re-run when something it shows changes. Unfiltered, each one covered every row ever
/// made (every old task, every Anchor instance, every habit entry), and each sync import marks all of them dirty; a framework race in that
/// path crashed a build (#418). A window of 14 days always holds today, this week's habit progress and a multi-day Anchor, and the date it is
/// cut at is the day the screen was made, so a screen left open for a week still looks back a week.
enum QueryWindow {
    static let days = 14

    static func start(now: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now.addingTimeInterval(-Double(days) * 86_400)
    }

    /// The always-alive shell only needs what is about to happen: Anchors from yesterday on.
    static func shellStart(now: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86_400)
    }

    /// Every live task (whatever its date, including the undated backlog) and the ones finished inside the window; never a dropped one.
    static func tasks(from: Date) -> Predicate<TaskItem> {
        // A task marked done with no completion time (it shouldn't happen) is kept: the fallback is the window's own start.
        #Predicate<TaskItem> { $0.droppedAt == nil && ($0.isCompleted == false || ($0.completedAt ?? from) >= from) }
    }

    static func liveTasks() -> Predicate<TaskItem> {
        #Predicate<TaskItem> { $0.droppedAt == nil && $0.isCompleted == false }
    }

    /// An Anchor whose window is not over by `from`: that keeps a multi-day one (the plants) that began earlier and is still open.
    static func anchors(from: Date) -> Predicate<AnchorInstance> {
        #Predicate<AnchorInstance> { $0.windowEnd >= from }
    }

    static func habitEntries(from: Date) -> Predicate<HabitEntry> {
        #Predicate<HabitEntry> { $0.date >= from }
    }

    static func plans(from: Date) -> Predicate<DayPlan> {
        #Predicate<DayPlan> { $0.date >= from }
    }

    static func nudgeLogs(from: Date) -> Predicate<NudgeLog> {
        #Predicate<NudgeLog> { $0.sentAt >= from }
    }

    /// A session still running is kept whatever its age; finished ones only inside the window.
    static func sessions(from: Date) -> Predicate<WorkSession> {
        #Predicate<WorkSession> { $0.endedAt == nil || $0.day >= from }
    }
}
