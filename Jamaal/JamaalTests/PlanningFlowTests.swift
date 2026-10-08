//
//  PlanningFlowTests.swift
//  JamaalTests
//

import Foundation
import SwiftData
import Testing
import JamaalCore
@testable import Jamaal

/// The app's side of Night Planning: which day it plans, stepping through the flow, the carry choices and their
/// undo, pushing a task out of tomorrow, the level, skipping and closing. The engine's own rules are tested in JamaalCore.
@MainActor
struct PlanningFlowTests {

    private let utc = TimeZone(identifier: "UTC")!
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }       // Mon 5 Oct 2026
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DayBoundary(rolloverMinute: 0, timeZone: utc).instant(of: d(day), atMinute: hour * 60 + minute)
    }

    private func context() throws -> ModelContext {
        let c = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        c.insert(UserSettings())
        return c
    }

    private func flow(_ c: ModelContext, mode: PlanningMode = .evening, now: Date) throws -> PlanningFlow {
        try PlanningFlow(context: c, mode: mode, now: { now }, timeZone: utc)
    }

    @discardableResult
    private func task(_ title: String, due: Int?, minutes: Int = 30, importance: Importance = .medium, in c: ModelContext) -> TaskItem {
        let t = TaskItem(title: title, dueDate: due.map { d($0).storedDate }, effortMinutes: minutes)
        t.importanceLevel = importance
        c.insert(t)
        return t
    }

    // MARK: Which day, and the steps

    @Test func theRailGoesBackToAnEarlierStepAndNeverForward() throws {
        let c = try context()
        task("Left over", due: 5, in: c)                       // carry has work
        let f = try flow(c, now: at(5, 20))
        f.next(); f.next(); f.next()                          // review → carry → build → load
        #expect(f.step == .load)
        f.go(to: .carry)
        #expect(f.step == .carry)
        f.go(to: .load)                                       // forward is Continue's job
        #expect(f.step == .carry)
        f.go(to: .review)
        #expect(f.step == .review)
        f.go(to: .review)                                     // already there
        #expect(f.step == .review)
    }

    @Test func goingBackSkipsCarryWhenThereIsNothingToCarry() throws {
        let c = try context()
        let f = try flow(c, now: at(5, 20))
        f.next()                                              // review → build (carry has no work, so it is skipped)
        #expect(f.step == .build)
        f.next()
        #expect(f.step == .load)
        f.go(to: .review)                                     // back over build, and carry is skipped again
        #expect(f.step == .review)
    }

    @Test func theRailOnlyKnowsTheStepsOfTheShortenedMorningFlow() throws {
        let c = try context()
        let f = try flow(c, mode: .morning, now: at(5, 9))
        #expect(f.steps == [.build, .load, .close])
        f.go(to: .review)                                     // not part of this flow: nothing happens
        #expect(f.step == .build)
    }

    @Test func anEveningPlansTomorrowAndReviewsToday() throws {
        let c = try context()
        let f = try flow(c, now: at(5, 20))
        #expect(f.forDate == d(6))
        #expect(f.reviewDate == d(5))
        #expect(f.step == .review)
        #expect(f.steps == [.review, .carry, .build, .load, .close])
    }

    @Test func afterMidnightButBeforeTheDayStartsItStillPlansTheMorningAhead() throws {
        let c = try context()
        let f = try flow(c, now: at(6, 0, 30))                                 // 00:30 on the 6th, the day starts 08:00
        #expect(f.forDate == d(6))
        #expect(f.reviewDate == d(5))
    }

    @Test func theMorningFlowIsShortenedAndPlansToday() throws {
        let c = try context()
        let f = try flow(c, mode: .morning, now: at(6, 9))
        #expect(f.forDate == d(6))
        #expect(f.steps == [.build, .load, .close])
        #expect(f.step == .build)
    }

    @Test func continuingPassesThroughCarryOnlyWhenThereIsSomethingToCarry() throws {
        let c = try context()
        let f = try flow(c, now: at(5, 20))
        f.next()
        #expect(f.step == .build)                                              // nothing left today: Carry is skipped
        let c2 = try context()
        task("Left over", due: 5, in: c2)
        let g = try flow(c2, now: at(5, 20))
        g.next()
        #expect(g.step == .carry)
        g.next()
        #expect(g.step == .build)
        g.back()
        #expect(g.step == .carry)
    }

    @Test func theStepPositionIsOneBasedAndCountsTheSteps() throws {
        let c = try context()
        task("Left over", due: 5, in: c)
        let f = try flow(c, now: at(5, 20))
        #expect(f.position == 1 && f.stepCount == 5)
        f.next()
        #expect(f.position == 2)
    }

    @Test func theSessionPersistsSoAReopenResumesWhereItWas() throws {
        let c = try context()
        task("Left over", due: 5, in: c)
        let first = try flow(c, now: at(5, 20))
        first.next()
        let again = try flow(c, now: at(5, 20, 5))
        #expect(again.step == .carry)
        #expect(try c.fetchCount(FetchDescriptor<NightPlanningSession>()) == 1)
    }

    // MARK: Carry

    @Test func keepingMovesATaskToTomorrowAndUndoPutsItBack() throws {
        let c = try context()
        let t = task("Left over", due: 5, in: c)
        let f = try flow(c, now: at(5, 20))
        #expect(f.carry(t, .keep) == .applied)
        #expect(t.dueDate == d(6).storedDate)
        #expect(t.deferralCount == 1)
        f.undoCarry(t)
        #expect(t.dueDate == d(5).storedDate)
        #expect(t.deferralCount == 0)
    }

    @Test func keepOnAThirdDeferralAsksForAPickerInstead() throws {
        let c = try context()
        let t = task("Slippy", due: 5, in: c)
        t.deferralCount = 2
        let f = try flow(c, now: at(5, 20))
        #expect(f.carry(t, .keep) == .needsPicker)
        #expect(t.dueDate == d(5).storedDate)
        #expect(f.carry(t, .later(d(12), .tooMuch)) == .applied)
        #expect(t.dueDate == d(12).storedDate)
    }

    @Test func droppingLeavesTheListAndIsUndoable() throws {
        let c = try context()
        let t = task("Let go", due: 5, in: c)
        let f = try flow(c, now: at(5, 20))
        #expect(f.carry(t, .drop) == .applied)
        #expect(t.droppedAt != nil)
        f.undoCarry(t)
        #expect(t.droppedAt == nil)
    }

    // MARK: Build, load, skip, close

    @Test func pushingATaskOutOfTomorrowReschedulesItWithoutCountingADeferral() throws {
        let c = try context()
        let t = task("Groceries", due: 6, in: c)
        let f = try flow(c, now: at(5, 20))
        f.pushOut(t)
        #expect(t.dueDate == d(7).storedDate)
        #expect(t.deferralCount == 0)
    }

    @Test func pullingInABacklogTaskDatesItTomorrow() throws {
        let c = try context()
        let t = task("Renew the passport", due: nil, importance: .low, in: c)
        let f = try flow(c, now: at(5, 20))
        f.pullIn(t)
        #expect(t.dueDate == d(6).storedDate)
    }

    @Test func theLevelIsWrittenTheMomentItIsChosen() throws {
        let c = try context()
        let f = try flow(c, now: at(5, 20))
        f.setLevel(.high)
        let plan = try #require(try c.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.capacityLevel == .high)
        #expect(try f.loadCheck().level == .high)
    }

    @Test func skippingEndsTheFlowWithoutAPlanAndKeepsCarryChoices() throws {
        let c = try context()
        let t = task("Left over", due: 5, in: c)
        let f = try flow(c, now: at(5, 20))
        _ = f.carry(t, .keep)
        f.skip()
        #expect(f.session.skippedAt != nil)
        #expect(try c.fetchCount(FetchDescriptor<DayPlan>()) == 0)
        #expect(t.dueDate == d(6).storedDate)
    }

    @Test func closingWritesTheSnapshotAndCountsTheNight() throws {
        let c = try context()
        task("Plan", due: 6, minutes: 90, in: c)
        let f = try flow(c, now: at(5, 20))
        let summary = try f.close()
        #expect(summary.taskCount == 1)
        #expect(summary.plannedMinutes == 90)
        #expect(summary.nightsPlanned == 1)
        #expect(f.session.isComplete)
        let plan = try #require(try c.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.plannedTaskMinutes == 90)
    }

    @Test func aClosedDayCanNoLongerUndoACarryChoice() throws {
        let c = try context()
        let t = task("Left over", due: 5, in: c)
        let f = try flow(c, now: at(5, 20))
        _ = f.carry(t, .keep)
        _ = try f.close()
        f.undoCarry(t)
        #expect(t.dueDate == d(6).storedDate)                                  // refused: stays moved
    }
}
