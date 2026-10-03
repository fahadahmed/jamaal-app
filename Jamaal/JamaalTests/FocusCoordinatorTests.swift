//
//  FocusCoordinatorTests.swift
//  JamaalTests
//

import Foundation
import SwiftData
import Testing
import JamaalCore
@testable import Jamaal

/// The app's side of focus sessions: Begin, the settle sheet when a second Begin arrives, Finish with its
/// five-second Undo, and nothing that blocks. The engine's own rules are tested in JamaalCore.
@MainActor
struct FocusCoordinatorTests {

    private let utc = TimeZone(identifier: "UTC")!

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
        func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    private struct World {
        let context: ModelContext
        let clock: Clock
        let coordinator: FocusCoordinator
    }

    private func world() throws -> World {
        let context = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        context.insert(UserSettings())
        let clock = Clock(Date(timeIntervalSince1970: 1_791_000_000))                   // an arbitrary morning
        let coordinator = FocusCoordinator(now: { clock.now }, timeZone: utc)
        coordinator.context = context
        return World(context: context, clock: clock, coordinator: coordinator)
    }

    private func task(_ title: String, in context: ModelContext, minutes: Int? = 60) -> TaskItem {
        let t = TaskItem(title: title, effortMinutes: minutes)
        context.insert(t)
        return t
    }

    private func habit(in context: ModelContext, target: Int = 20) -> HabitTimeWindow {
        let h = Habit(title: "Read"); h.habitKind = .timed
        context.insert(h)
        let w = HabitTimeWindow(); w.target = target
        context.insert(w); w.habit = h
        return w
    }

    private var live: (ModelContext) -> WorkSession? { { FocusSessions.liveSession(in: $0) } }

    // MARK: Begin and settle

    @Test func beginningWithNothingRunningStartsASession() throws {
        let w = try world()
        let t = task("Draft", in: w.context)
        w.coordinator.begin(.task(t))
        let session = try #require(live(w.context))
        #expect(session.task === t)
        #expect(w.coordinator.settling == nil)
        #expect(!w.coordinator.isShowingFocus)                               // the chip appears; the screen opens on a tap
    }

    @Test func aSecondBeginRaisesTheSettleSheetAndStartsNothing() throws {
        let w = try world()
        let a = task("Draft", in: w.context), b = task("Call", in: w.context)
        w.coordinator.begin(.task(a))
        w.coordinator.begin(.task(b))
        let settling = try #require(w.coordinator.settling)
        #expect(settling.session.task === a)
        #expect(settling.pendingTitle == "Call")
        #expect(live(w.context)?.task === a)                                 // still the first
    }

    @Test func settlingAsStopForNowKeepsTheTimeThenBeginsTheNext() throws {
        let w = try world()
        let a = task("Draft", in: w.context), b = task("Call", in: w.context)
        w.coordinator.begin(.task(a))
        w.clock.advance(24 * 60)
        w.coordinator.begin(.task(b))
        w.coordinator.settle(.stopForNow)
        #expect(a.sessions?.first?.actualSeconds == 24 * 60)
        #expect(!a.isCompleted)
        #expect(live(w.context)?.task === b)
        #expect(w.coordinator.settling == nil)
    }

    @Test func settlingAsDoneCompletesTheFirstAndAsDeferOrDropResolvesIt() throws {
        for (choice, check) in [
            (SettleChoice.done, { (t: TaskItem) in t.isCompleted }),
            (.drop, { (t: TaskItem) in t.droppedAt != nil }),
            (.deferToTomorrow, { (t: TaskItem) in t.deferralCount == 1 }),
        ] as [(SettleChoice, (TaskItem) -> Bool)] {
            let w = try world()
            let a = task("Draft", in: w.context), b = task("Call", in: w.context)
            a.dueDate = w.coordinator.today(in: w.context).storedDate
            w.coordinator.begin(.task(a))
            w.coordinator.begin(.task(b))
            w.coordinator.settle(choice)
            #expect(check(a))
            #expect(live(w.context)?.task === b)
        }
    }

    @Test func cancellingTheSettleSheetChangesNothing() throws {
        let w = try world()
        let a = task("Draft", in: w.context), b = task("Call", in: w.context)
        w.coordinator.begin(.task(a))
        w.coordinator.begin(.task(b))
        w.coordinator.cancelSettle()
        #expect(w.coordinator.settling == nil)
        #expect(live(w.context)?.task === a)
        #expect(b.sessions?.isEmpty ?? true)
    }

    @Test func aTimedHabitSharesTheOneTimerAndSettlesWithLogIt() throws {
        let w = try world()
        let a = task("Draft", in: w.context)
        let window = habit(in: w.context)
        w.coordinator.begin(.task(a))
        w.coordinator.begin(.habit(window))
        #expect(w.coordinator.settling?.pendingTitle == "Read")
        w.coordinator.settle(.stopForNow)
        #expect(live(w.context)?.habitWindow === window)
        // And a habit running, then a task: the habit settles with Log it.
        w.clock.advance(15 * 60)
        w.coordinator.begin(.task(a))
        #expect(w.coordinator.settling?.session.habitWindow === window)
        w.coordinator.settle(.logIt)
        #expect(live(w.context)?.task === a)
        let today = w.coordinator.today(in: w.context)
        let entry = window.entries?.first { CalendarDate(storedDate: $0.date) == today }
        #expect(entry?.amount == 15)
    }

    @Test func aTaskThatIsNoLongerLiveCannotBeginAndTheChipStaysAway() throws {
        let w = try world()
        let t = task("Done already", in: w.context)
        t.isCompleted = true
        w.coordinator.begin(.task(t))
        #expect(live(w.context) == nil)
    }

    // MARK: Pause, finish, undo

    @Test func pausingAndResumingGoThroughTheEngine() throws {
        let w = try world()
        let t = task("Draft", in: w.context)
        w.coordinator.begin(.task(t))
        let session = try #require(live(w.context))
        w.coordinator.pause(session)
        #expect(session.pausedAt != nil)
        w.clock.advance(120)
        w.coordinator.resume(session)
        #expect(session.pausedAt == nil)
        #expect(session.pausedSeconds == 120)
    }

    @Test func finishingAsDoneCompletesTheTaskAndOffersUndo() throws {
        let w = try world()
        let t = task("Draft", in: w.context)
        w.coordinator.begin(.task(t))
        let session = try #require(live(w.context))
        w.coordinator.isShowingFocus = true
        w.clock.advance(74 * 60)
        w.coordinator.finish(session, as: .done, note: "Sent to Priya")
        #expect(t.isCompleted)
        #expect(t.notes?.hasSuffix("Sent to Priya") == true)
        #expect(!w.coordinator.isShowingFocus)
        let toast = try #require(w.coordinator.toast)
        #expect(toast.title == "Draft")
    }

    @Test func stoppingForNowKeepsTheTaskLiveAndOffersNoUndo() throws {
        let w = try world()
        let t = task("Draft", in: w.context)
        w.coordinator.begin(.task(t))
        let session = try #require(live(w.context))
        w.clock.advance(10 * 60)
        w.coordinator.finish(session, as: .stopForNow, note: nil)
        #expect(!t.isCompleted)
        #expect(w.coordinator.toast == nil)
        #expect(t.sessions?.first?.actualSeconds == 10 * 60)
    }

    @Test func undoWithinFiveSecondsReopensTheSessionAndTheTask() throws {
        let w = try world()
        let t = task("Draft", in: w.context)
        w.coordinator.begin(.task(t))
        let session = try #require(live(w.context))
        w.clock.advance(30 * 60)
        w.coordinator.finish(session, as: .done, note: "line")
        w.clock.advance(3)
        w.coordinator.undoToast()
        #expect(!t.isCompleted)
        #expect(live(w.context) != nil)
        #expect(w.coordinator.toast == nil)
        #expect(t.notes == nil)
    }

    @Test func undoAfterTheWindowIsRefusedAndTheToastGoes() throws {
        let w = try world()
        let t = task("Draft", in: w.context)
        w.coordinator.begin(.task(t))
        let session = try #require(live(w.context))
        w.coordinator.finish(session, as: .done, note: nil)
        w.clock.advance(6)
        w.coordinator.undoToast()
        #expect(t.isCompleted)
        #expect(w.coordinator.toast == nil)
    }

    @Test func theToastExpiresOnItsOwnAfterFiveSeconds() throws {
        let w = try world()
        let t = task("Draft", in: w.context)
        w.coordinator.begin(.task(t))
        let session = try #require(live(w.context))
        w.coordinator.finish(session, as: .done, note: nil)
        w.clock.advance(4)
        w.coordinator.expireToastIfNeeded()
        #expect(w.coordinator.toast != nil)
        w.clock.advance(2)
        w.coordinator.expireToastIfNeeded()
        #expect(w.coordinator.toast == nil)
    }

    @Test func beginningAgainClearsAnOldToast() throws {
        let w = try world()
        let a = task("Draft", in: w.context), b = task("Call", in: w.context)
        w.coordinator.begin(.task(a))
        let session = try #require(live(w.context))
        w.coordinator.finish(session, as: .done, note: nil)
        w.coordinator.begin(.task(b))
        #expect(w.coordinator.toast == nil)
    }

    @Test func settlingWorksOnTheMainContextThatTheAppUses() throws {
        let container = try JamaalSchema.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(UserSettings())
        let clock = Clock(Date(timeIntervalSince1970: 1_791_000_000))
        let coordinator = FocusCoordinator(now: { clock.now }, timeZone: utc)
        coordinator.context = context
        let a = task("Draft", in: context), b = task("Call", in: context)
        coordinator.begin(.task(a))
        clock.advance(16)
        coordinator.begin(.task(b))
        #expect(coordinator.settling != nil)
        coordinator.settle(.stopForNow)
        #expect(a.sessions?.first?.endedAt != nil)
        #expect(FocusSessions.liveSession(in: context)?.task === b)
    }
}
