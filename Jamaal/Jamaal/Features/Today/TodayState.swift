//
//  TodayState.swift
//  Jamaal
//

import Foundation

/// What is on Today, counted: enough to say which Today it is.
struct TodayContent {
    var remainingTasks = 0
    var completedTasks = 0
    /// Due tasks the level hides (still counted, so a day with only those isn't "blank").
    var alsoToday = 0
    var anchors = 0
    var pendingAnchors = 0
    var habits = 0
    var unfinishedHabits = 0
}

/// A blank day (nothing due at all), a finished one (everything decided), or the usual.
enum TodayState: Equatable {
    case blank, allDone, normal

    static func of(_ c: TodayContent) -> TodayState {
        let anything = c.remainingTasks + c.completedTasks + c.alsoToday + c.anchors + c.habits
        if anything == 0 { return .blank }
        return c.remainingTasks == 0 && c.pendingAnchors == 0 && c.unfinishedHabits == 0 ? .allDone : .normal
    }
}
