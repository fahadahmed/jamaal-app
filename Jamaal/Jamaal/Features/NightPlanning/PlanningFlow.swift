//
//  PlanningFlow.swift
//  Jamaal
//

import Foundation
import Observation
import SwiftData
import JamaalCore

enum CarryOutcome: Equatable { case applied, needsPicker, failed }

/// The app's side of Night Planning (JamaalCore, module 4). The engine owns every rule and the session persists, so
/// leaving the app mid-flow resumes at the same step; this holds the day being planned, the steps, and what a carry
/// choice needs to be undone (until the day is closed).
@MainActor
@Observable
final class PlanningFlow: Identifiable {
    let id = UUID()
    let context: ModelContext
    let boundary: DayBoundary
    let mode: PlanningMode
    let forDate: CalendarDate
    let reviewDate: CalendarDate
    let settings: UserSettings
    private(set) var session: NightPlanningSession
    @ObservationIgnored private var results: [UUID: CarryResult] = [:]
    @ObservationIgnored private let now: () -> Date

    init(context: ModelContext, mode: PlanningMode, now: @escaping () -> Date = { .now }, timeZone: TimeZone = .current) throws {
        self.context = context
        self.mode = mode
        self.now = now
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
            .min { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) } ?? UserSettings()
        self.settings = settings
        let boundary = DayBoundary(rolloverMinute: settings.rolloverMinute, timeZone: timeZone)
        self.boundary = boundary
        switch mode {
        case .evening:
            let target = boundary.planningTarget(at: now(), dayStartMinute: settings.dayStartMinute)
            forDate = target.forDate
            reviewDate = target.reviewDate
        case .morning:
            forDate = boundary.logicalDate(at: now())
            reviewDate = forDate.addingDays(-1)
        }
        session = try NightPlanning.open(forDate: forDate, mode: mode, now: now(), context: context)
    }

    // MARK: Steps

    var steps: [PlanningStep] { NightPlanning.steps(for: session) }
    var step: PlanningStep { session.step }
    var stepCount: Int { steps.count }
    var position: Int { (steps.firstIndex(of: step) ?? 0) + 1 }
    var isFirstStep: Bool { position == 1 }

    /// Carry has something to show: tasks left over, or ones already moved or dropped from the reviewed day (so a
    /// choice can still be changed).
    private var carryHasWork: Bool {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return !NightPlanning.carryItems(tasks: tasks, reviewing: reviewDate, boundary: boundary).isEmpty
    }

    func next() { NightPlanning.advance(session, carryHasWork: carryHasWork) }
    func back() { NightPlanning.back(session, carryHasWork: carryHasWork) }

    /// *Skip tonight*: no plan is written, and choices already made stay.
    func skip() { NightPlanning.skip(session, now: now()) }

    func close() throws -> ClosingSummary {
        try NightPlanning.close(session, boundary: boundary, now: now(), context: context)
    }

    // MARK: Reading each step

    func review() throws -> DayReview {
        try NightPlanning.review(reviewDate: reviewDate, boundary: boundary, now: now(), context: context)
    }

    func carryItems() -> [CarryItem] {
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        return NightPlanning.carryItems(tasks: tasks, reviewing: reviewDate, boundary: boundary)
    }

    func build() throws -> PlanBuild {
        try NightPlanning.build(forDate: forDate, boundary: boundary, now: now(), context: context)
    }

    func loadCheck() throws -> LoadCheck {
        try NightPlanning.loadCheck(forDate: forDate, boundary: boundary, now: now(), context: context)
    }

    // MARK: Acting

    func carry(_ task: TaskItem, _ choice: CarryChoice) -> CarryOutcome {
        do {
            results[task.id] = try NightPlanning.carry(
                task, choice, reviewing: reviewDate, forDate: forDate, now: now(), boundary: boundary, context: context)
            return .applied
        } catch CarryError.pickerRequired {
            return .needsPicker
        } catch {
            return .failed
        }
    }

    func canUndoCarry(_ task: TaskItem) -> Bool { results[task.id] != nil && !session.isComplete }

    func undoCarry(_ task: TaskItem) {
        guard let result = results[task.id] else { return }
        if (try? NightPlanning.undoCarry(result, session: session, context: context)) != nil { results[task.id] = nil }
    }

    /// Out of the planned day to the next: rescheduling, never a deferral.
    func pushOut(_ task: TaskItem) {
        try? NightPlanning.move(task, to: forDate.addingDays(1), reviewing: reviewDate, now: now(), boundary: boundary, context: context)
    }

    /// Into the planned day (a backlog task or one due later): rescheduling too.
    func pullIn(_ task: TaskItem) {
        try? NightPlanning.move(task, to: forDate, reviewing: reviewDate, now: now(), boundary: boundary, context: context)
    }

    func setLevel(_ level: CapacityLevel) { NightPlanning.setCapacity(level, forDate: forDate, context: context) }

    // MARK: The normal-day line on the Load step (at most once in Night Planning)

    func normalDayOffer() -> Int? {
        try? DaySettings.normalDaySuggestionForPlanning(in: context, settings: settings, today: boundary.logicalDate(at: now()))
    }

    func markNormalDayOfferShown(_ minutes: Int) { try? DaySettings.logShownInPlanning(minutes, in: context, now: now()) }
    func acceptNormalDay(_ minutes: Int) { try? DaySettings.setNormalDay(minutes, on: settings) }
    func declineNormalDay(_ minutes: Int) { try? DaySettings.decline(minutes, in: context, now: now()) }

    /// The engine's one specific suggestion on the Load step: move a task to the day it names (`false` if there is none).
    @discardableResult
    func moveSuggested(_ suggestion: MoveSuggestion, to date: CalendarDate? = nil) -> Bool {
        guard let target = date ?? suggestion.target else { return false }
        try? NightPlanning.move(suggestion.task, to: target, reviewing: reviewDate, now: now(), boundary: boundary, context: context)
        return true
    }
}
