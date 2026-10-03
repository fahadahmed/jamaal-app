//
//  FocusCoordinator.swift
//  Jamaal
//

import Foundation
import Observation
import SwiftData
import JamaalCore

/// The app's side of focus sessions. The engine (JamaalCore, module 8) owns every rule; this holds what a screen
/// needs between taps: whether the focus screen is open, the settle sheet when a second Begin arrives, and the
/// five-second Undo after Done. Nothing here ever blocks the rest of the app.
@MainActor
@Observable
final class FocusCoordinator {

    enum Target {
        case task(TaskItem)
        case habit(HabitTimeWindow)

        var title: String {
            switch self {
            case .task(let task): task.title
            case .habit(let window): window.habit?.title ?? ""
            }
        }
    }

    /// The running session that has to be settled before `pending` can begin.
    struct Settling {
        var session: WorkSession
        var pending: Target?
        var pendingTitle: String { pending?.title ?? "" }
    }

    /// "Done · title  Undo", for five seconds.
    struct Toast {
        var title: String
        var session: WorkSession
        var result: FinishResult
        var at: Date
    }

    var context: ModelContext?
    var isShowingFocus = false
    private(set) var settling: Settling?
    private(set) var toast: Toast?

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let timeZone: TimeZone

    init(now: @escaping () -> Date = { .now }, timeZone: TimeZone = .current) {
        self.now = now
        self.timeZone = timeZone
    }

    private var boundary: DayBoundary? {
        context.map { TodayDay.boundary(in: $0, timeZone: timeZone) }
    }

    func today(in context: ModelContext) -> CalendarDate {
        TodayDay.boundary(in: context, timeZone: timeZone).logicalDate(at: now())
    }

    // MARK: Begin and settle

    /// Starts a session, or — when one is already running — raises the settle sheet and starts nothing yet.
    func begin(_ target: Target) {
        guard let context else { return }
        toast = nil
        if let live = FocusSessions.liveSession(in: context) {
            settling = Settling(session: live, pending: target)
            return
        }
        start(target)
    }

    private func start(_ target: Target) {
        guard let context, let boundary else { return }
        switch target {
        case .task(let task): _ = try? FocusSessions.begin(task: task, now: now(), boundary: boundary, context: context)
        case .habit(let window): _ = try? FocusSessions.begin(habitWindow: window, now: now(), boundary: boundary, context: context)
        }
    }

    /// Settles the running session (its time is kept whichever is chosen) and then begins what was waiting.
    func settle(_ choice: SettleChoice) {
        guard let context, let boundary, let current = settling else { return }
        settling = nil
        _ = try? FocusSessions.settle(current.session, as: choice, now: now(), boundary: boundary, context: context)
        if let pending = current.pending, FocusSessions.liveSession(in: context) == nil { start(pending) }
    }

    func cancelSettle() { settling = nil }

    // MARK: Pause, resume, finish

    func pause(_ session: WorkSession) { try? FocusSessions.pause(session, now: now()) }
    func resume(_ session: WorkSession) { try? FocusSessions.resume(session, now: now()) }

    /// Finishes the session. *Done* on a task leaves a five-second Undo; *Stop for now* keeps the time and the task.
    func finish(_ session: WorkSession, as choice: FinishChoice, note: String?) {
        guard let context, let boundary else { return }
        let title = session.task?.title ?? session.habitWindow?.habit?.title ?? ""
        isShowingFocus = false
        guard let result = try? FocusSessions.finish(session, as: choice, note: note, now: now(), boundary: boundary, context: context) else { return }
        toast = choice == .done && result.completedTask ? Toast(title: title, session: session, result: result, at: now()) : nil
    }

    // MARK: The undo toast

    func undoToast() {
        guard let context, let boundary, let current = toast else { return }
        toast = nil
        try? FocusSessions.undoFinish(current.session, result: current.result, now: now(), boundary: boundary, context: context)
    }

    func dismissToast() { toast = nil }

    func expireToastIfNeeded() {
        guard let toast, now().timeIntervalSince(toast.at) > FocusSessions.undoWindowSeconds else { return }
        self.toast = nil
    }
}
