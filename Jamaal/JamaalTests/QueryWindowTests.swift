//
//  QueryWindowTests.swift
//  JamaalTests
//

import Foundation
import SwiftData
import Testing
import JamaalCore
@testable import Jamaal

/// The queries Today and the shell observe look back a fixed window instead of at every row ever made (#418). They must still contain
/// everything Today can show, and leave out what it never can.
@MainActor
struct QueryWindowTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var from: Date { QueryWindow.start(now: now) }
    private func ago(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }

    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }

    private func titles<T: PersistentModel>(_ context: ModelContext, _ predicate: Predicate<T>, _ title: (T) -> String) throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<T>(predicate: predicate)).map(title))
    }

    @Test func theWindowIsFourteenDays() {
        #expect(QueryWindow.days == 14)
        #expect(abs(now.timeIntervalSince(from) - 14 * 86_400) < 3_700, "to within a daylight-saving hour")
    }

    @Test func tasksKeepEveryLiveOneAndOnlyRecentlyCompletedOnesAndNeverDroppedOnes() throws {
        let c = try context()
        func add(_ title: String, done: Date? = nil, dropped: Date? = nil) {
            let t = TaskItem(title: title); t.isCompleted = done != nil; t.completedAt = done; t.droppedAt = dropped; c.insert(t)
        }
        add("live")
        add("done yesterday", done: ago(1))
        add("done long ago", done: ago(60))
        add("dropped", dropped: ago(2))
        #expect(try titles(c, QueryWindow.tasks(from: from), \TaskItem.title) == ["live", "done yesterday"])
    }

    @Test func anchorsKeepAnythingWhoseWindowIsNotOverIncludingAMultiDayOneThatStartedEarlier() throws {
        let c = try context()
        func add(_ title: String, start: Date, end: Date) {
            let a = Anchor(title: title); a.windowStart = start; a.windowEnd = end; c.insert(a)
        }
        add("today", start: ago(0), end: now.addingTimeInterval(3_600))
        add("tomorrow", start: now.addingTimeInterval(86_400), end: now.addingTimeInterval(90_000))
        add("plants, open since last week", start: ago(9), end: now.addingTimeInterval(2 * 86_400))
        add("old", start: ago(40), end: ago(40).addingTimeInterval(3_600))
        #expect(try titles(c, QueryWindow.anchors(from: from), \Anchor.title) == ["today", "tomorrow", "plants, open since last week"])
    }

    @Test func habitEntriesPlansAndLogsKeepOnlyTheWindow() throws {
        let c = try context()
        let recent = HabitEntry(); recent.date = ago(3); recent.amount = 1
        let old = HabitEntry(); old.date = ago(50); old.amount = 2
        c.insert(recent); c.insert(old)
        #expect(try c.fetch(FetchDescriptor<HabitEntry>(predicate: QueryWindow.habitEntries(from: from))).map(\.amount) == [1])

        let planNew = DayPlan(); planNew.date = ago(1); let planOld = DayPlan(); planOld.date = ago(30)
        c.insert(planNew); c.insert(planOld)
        #expect(try c.fetch(FetchDescriptor<DayPlan>(predicate: QueryWindow.plans(from: from))).count == 1)

        let logNew = NudgeLog(); logNew.sentAt = ago(2); let logOld = NudgeLog(); logOld.sentAt = ago(90)
        c.insert(logNew); c.insert(logOld)
        #expect(try c.fetch(FetchDescriptor<NudgeLog>(predicate: QueryWindow.nudgeLogs(from: from))).count == 1)
    }

    @Test func aSessionStillRunningIsKeptWhateverItsAgeAndFinishedOnesOnlyWithinTheWindow() throws {
        let c = try context()
        func add(_ outcome: String, day: Date, ended: Date?) {
            let s = WorkSession(); s.outcome = outcome; s.day = day; s.endedAt = ended; c.insert(s)
        }
        add("running", day: ago(30), ended: nil)
        add("finished", day: ago(2), ended: ago(2))
        add("finished", day: ago(60), ended: ago(60))
        #expect(try c.fetch(FetchDescriptor<WorkSession>(predicate: QueryWindow.sessions(from: from))).count == 2)
    }

    @Test func theShellSeesOnlyLiveTasksAndAnchorsFromYesterdayOn() throws {
        let c = try context()
        let live = TaskItem(title: "live"); let done = TaskItem(title: "done"); done.isCompleted = true; done.completedAt = ago(1)
        c.insert(live); c.insert(done)
        #expect(try titles(c, QueryWindow.liveTasks(), \TaskItem.title) == ["live"])
        let today = Anchor(title: "today"); today.windowEnd = now.addingTimeInterval(3_600)
        let old = Anchor(title: "old"); old.windowEnd = ago(10)
        c.insert(today); c.insert(old)
        #expect(try titles(c, QueryWindow.anchors(from: QueryWindow.shellStart(now: now)), \Anchor.title) == ["today"])
    }
}
