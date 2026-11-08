//
//  EditUndoCenterTests.swift
//  JamaalTests
//

import Foundation
import SwiftData
import Testing
import JamaalCore
@testable import Jamaal

@MainActor
struct EditUndoCenterTests {
    private func world() throws -> (ModelContext, TaskItem) {
        let context = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        let task = TaskItem(title: "Call the clinic back", dueDate: nil, effortMinutes: 15)
        context.insert(task)
        return (context, task)
    }

    @Test func aVisitWithNoChangeShowsNoToast() throws {
        let (_, task) = try world()
        let center = EditUndoCenter()
        center.visitEnded(task: task, snapshot: TaskEditing.snapshot(task))
        #expect(center.toast == nil)
    }

    @Test func aChangedVisitShowsOneToastNamingTheChangeAndUndoPutsItBack() throws {
        let (context, task) = try world()
        let center = EditUndoCenter()
        let snapshot = TaskEditing.snapshot(task)
        TaskEditing.setEffort(task, minutes: 30)
        center.visitEnded(task: task, snapshot: snapshot)
        #expect(center.toast?.text == "Call the clinic back · now 30 min")
        center.undo(in: context)
        #expect(task.effortMinutes == 15)
        #expect(center.toast == nil)
    }

    @Test func theToastGoesAfterFiveSeconds() throws {
        let (_, task) = try world()
        var clock = Date(timeIntervalSince1970: 1_000)
        let center = EditUndoCenter(now: { clock })
        let snapshot = TaskEditing.snapshot(task)
        TaskEditing.setEffort(task, minutes: 45)
        center.visitEnded(task: task, snapshot: snapshot)
        clock = clock.addingTimeInterval(4)
        center.expireIfNeeded()
        #expect(center.toast != nil)
        clock = clock.addingTimeInterval(1.5)
        center.expireIfNeeded()
        #expect(center.toast == nil)
    }

    @Test func aNewVisitReplacesTheToast() throws {
        let (_, task) = try world()
        let center = EditUndoCenter()
        let first = TaskEditing.snapshot(task)
        TaskEditing.setEffort(task, minutes: 30)
        center.visitEnded(task: task, snapshot: first)
        let second = TaskEditing.snapshot(task)
        TaskEditing.setEffort(task, minutes: 60)
        center.visitEnded(task: task, snapshot: second)
        #expect(center.toast?.text == "Call the clinic back · now 1h")
    }
}
