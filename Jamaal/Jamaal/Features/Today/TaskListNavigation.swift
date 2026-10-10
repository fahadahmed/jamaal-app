//
//  TaskListNavigation.swift
//  Jamaal
//

import Foundation

/// Which task the arrow keys select next on Today (a Mac, with the detail panel beside the list). It moves one
/// step and stops at the ends; with nothing selected, down picks the first and up the last.
enum TaskListNavigation {
    enum Step { case next, previous }

    static func move(_ step: Step, from current: UUID?, in ids: [UUID]) -> UUID? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            return step == .next ? ids.first : ids.last
        }
        switch step {
        case .next: return ids[min(index + 1, ids.count - 1)]
        case .previous: return ids[max(index - 1, 0)]
        }
    }
}
