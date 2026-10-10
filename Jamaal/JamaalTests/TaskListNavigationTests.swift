//
//  TaskListNavigationTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// Moving through Today's tasks with the arrow keys: one step at a time, stopping at the ends.
struct TaskListNavigationTests {

    private let a = UUID(), b = UUID(), c = UUID()
    private var ids: [UUID] { [a, b, c] }

    @Test func downMovesToTheNextTask() {
        #expect(TaskListNavigation.move(.next, from: a, in: ids) == b)
        #expect(TaskListNavigation.move(.next, from: b, in: ids) == c)
    }

    @Test func upMovesToThePreviousTask() {
        #expect(TaskListNavigation.move(.previous, from: c, in: ids) == b)
        #expect(TaskListNavigation.move(.previous, from: b, in: ids) == a)
    }

    @Test func itStopsAtTheEndsInsteadOfWrapping() {
        #expect(TaskListNavigation.move(.next, from: c, in: ids) == c)
        #expect(TaskListNavigation.move(.previous, from: a, in: ids) == a)
    }

    @Test func withNothingSelectedDownPicksTheFirstAndUpTheLast() {
        #expect(TaskListNavigation.move(.next, from: nil, in: ids) == a)
        #expect(TaskListNavigation.move(.previous, from: nil, in: ids) == c)
    }

    @Test func aSelectionThatLeftTheListIsTreatedAsNone() {
        let gone = UUID()                                   // dropped or filtered away
        #expect(TaskListNavigation.move(.next, from: gone, in: ids) == a)
        #expect(TaskListNavigation.move(.previous, from: gone, in: ids) == c)
    }

    @Test func anEmptyListHasNothingToSelect() {
        #expect(TaskListNavigation.move(.next, from: nil, in: []) == nil)
        #expect(TaskListNavigation.move(.previous, from: a, in: []) == nil)
    }

    @Test func aSingleTaskStaysSelected() {
        #expect(TaskListNavigation.move(.next, from: a, in: [a]) == a)
        #expect(TaskListNavigation.move(.previous, from: a, in: [a]) == a)
    }
}
