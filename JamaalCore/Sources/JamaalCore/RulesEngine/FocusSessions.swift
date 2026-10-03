import Foundation
import SwiftData

public enum FocusSessionError: Error, Equatable, Sendable {
    /// One timer at a time: a second Begin is refused until the live session (named here) is settled.
    case alreadyRunning(UUID)
    case notRunning
    case alreadyPaused
    case notPaused
    case taskNotLive
    /// *Defer* and *Drop* don't exist for a habit's session; only *Log it* and *Stop for now*.
    case notForAHabit
    /// *Log it* exists only for a habit's session.
    case notForATask
    /// The five-second undo has passed.
    case undoExpired
}

public enum FocusState: Sendable, Hashable {
    case running
    /// Elapsed has passed the estimate. A state, never an event: no alarm, colour change or nudge.
    case overrun
    /// Only by an explicit pause; backgrounding the app never pauses.
    case paused
    case ended
}

/// How a session finishes: *Done* completes the task, *Stop for now* keeps the time and leaves it live.
public enum FinishChoice: Sendable { case done, stopForNow }

/// What the settle sheet offers when a second Begin is tapped (or the chip is settled).
public enum SettleChoice: Sendable { case done, stopForNow, deferToTomorrow, drop, logIt }

public struct FinishResult: Equatable, Sendable {
    /// The timestamped line appended to the task's note, if any, so an undo can remove it.
    public var appendedNote: String?
    public var completedTask: Bool
}

/// The "pick it back up" row after a session was auto-closed at the rollover.
public struct PickUpRow {
    public var task: TaskItem
    public var session: WorkSession
}

/// The single most urgent Anchor line for the chip. Never blocks anything.
public struct ApproachingEdge: Equatable, Sendable {
    public enum Kind: Sendable { case closing, opening }
    public var title: String
    public var minutes: Int
    public var kind: Kind

    public init(title: String, minutes: Int, kind: Kind) {
        self.title = title
        self.minutes = minutes
        self.kind = kind
    }
}

/// Module 8: focus sessions (docs/schema/task.md, "Focus sessions"; docs/schema/habit.md, "Timed habits").
///
/// Elapsed time is always derived from `startedAt`, never accumulated in memory, so a killed app
/// rebuilds a session exactly. There is one live session across tasks and timed habits.
public enum FocusSessions {

    /// The undo toast after a finish lasts this long.
    public static let undoWindowSeconds: TimeInterval = 5
    /// A fixed Anchor about to open is shown from this many minutes before it does. Tunable.
    static let openingLeadMinutes = 30

    // MARK: Derived

    /// Elapsed minus pauses, including a pause still in progress; never negative.
    public static func elapsedSeconds(of session: WorkSession, at now: Date) -> Int {
        let end = session.endedAt ?? now
        let pausedSoFar = session.pausedAt.map { max(0, Int(end.timeIntervalSince($0))) } ?? 0
        return max(0, Int(end.timeIntervalSince(session.startedAt)) - session.pausedSeconds - pausedSoFar)
    }

    public static func state(of session: WorkSession, at now: Date) -> FocusState {
        if session.endedAt != nil { return .ended }
        if session.pausedAt != nil { return .paused }
        if let estimate = session.estimateMinutes, elapsedSeconds(of: session, at: now) > estimate * 60 { return .overrun }
        return .running
    }

    /// Time spent on a task: its finished sessions' time plus the live one's elapsed time (pauses excluded).
    public static func trackedSeconds(of task: TaskItem, at now: Date) -> Int {
        (task.sessions ?? []).reduce(0) { total, session in
            total + (session.endedAt == nil && session.outcome == SessionOutcome.running.rawValue
                ? elapsedSeconds(of: session, at: now) : session.actualSeconds)
        }
    }

    /// The live session, if any (the earliest-started if a clash left two).
    @MainActor
    public static func liveSession(in context: ModelContext) -> WorkSession? {
        let running = SessionOutcome.running.rawValue
        let live = (try? context.fetch(FetchDescriptor<WorkSession>(predicate: #Predicate { $0.outcome == running && $0.endedAt == nil }))) ?? []
        return live.min { ($0.startedAt, $0.id.uuidString) < ($1.startedAt, $1.id.uuidString) }
    }

    // MARK: Begin, pause, resume

    @MainActor
    public static func begin(task: TaskItem, now: Date, boundary: DayBoundary, context: ModelContext) throws -> WorkSession {
        if let live = liveSession(in: context) { throw FocusSessionError.alreadyRunning(live.id) }
        guard !task.isCompleted, task.droppedAt == nil else { throw FocusSessionError.taskNotLive }
        let session = WorkSession()
        session.startedAt = now
        session.day = boundary.logicalDate(at: now).storedDate
        session.estimateMinutes = task.effortMinutes
        context.insert(session)
        session.task = task
        return session
    }

    /// A timed habit's session. Its estimate is the target in minutes.
    @MainActor
    public static func begin(habitWindow window: HabitTimeWindow, now: Date, boundary: DayBoundary, context: ModelContext) throws -> WorkSession {
        if let live = liveSession(in: context) { throw FocusSessionError.alreadyRunning(live.id) }
        let session = WorkSession()
        session.startedAt = now
        session.day = boundary.logicalDate(at: now).storedDate
        session.estimateMinutes = window.habit?.habitKind == .timed ? window.target : window.effortMinutes
        context.insert(session)
        session.habitWindow = window
        return session
    }

    public static func pause(_ session: WorkSession, now: Date) throws {
        guard session.endedAt == nil else { throw FocusSessionError.notRunning }
        guard session.pausedAt == nil else { throw FocusSessionError.alreadyPaused }
        session.pausedAt = now
    }

    public static func resume(_ session: WorkSession, now: Date) throws {
        guard let pausedAt = session.pausedAt else { throw FocusSessionError.notPaused }
        session.pausedSeconds += max(0, Int(now.timeIntervalSince(pausedAt)))
        session.pausedAt = nil
    }

    // MARK: Finish and undo

    /// Ends a session. *Done* completes the task; *Stop for now* keeps the time and leaves the task live
    /// ("abandoning is not failing"). An optional note is appended to the task as a timestamped line.
    /// A habit session just adds its minutes to that day's entry either way.
    @MainActor
    @discardableResult
    public static func finish(
        _ session: WorkSession, as choice: FinishChoice, note: String?, now: Date,
        boundary: DayBoundary, context: ModelContext
    ) throws -> FinishResult {
        guard session.outcome == SessionOutcome.running.rawValue, session.endedAt == nil else { throw FocusSessionError.notRunning }
        close(session, at: now, as: choice == .done ? .finished : .abandoned)

        var result = FinishResult(appendedNote: nil, completedTask: false)
        if let task = session.task {
            result.appendedNote = append(note: note, to: task, now: now, boundary: boundary)
            if choice == .done {
                TaskActions.complete(task, now: now, boundary: boundary, context: context)
                result.completedTask = true
            }
        }
        if let window = session.habitWindow {
            HabitSessions.recompute(window, on: CalendarDate(storedDate: session.day), now: now, context: context)
        }
        return result
    }

    /// Reopens a just-finished session within the toast's five seconds. The toast's seconds are added
    /// to the pauses, so they don't count as work; the task is un-completed (removing an untouched next
    /// instance of a repeating task) and the appended note is removed.
    @MainActor
    public static func undoFinish(
        _ session: WorkSession, result: FinishResult, now: Date, boundary: DayBoundary, context: ModelContext
    ) throws {
        guard let endedAt = session.endedAt else { throw FocusSessionError.notRunning }
        guard now.timeIntervalSince(endedAt) <= undoWindowSeconds else { throw FocusSessionError.undoExpired }
        if let live = liveSession(in: context) { throw FocusSessionError.alreadyRunning(live.id) }

        if result.completedTask, let task = session.task {
            try TaskActions.uncomplete(task, boundary: boundary, context: context)
        }
        if let line = result.appendedNote, let task = session.task, var notes = task.notes, notes.hasSuffix(line) {
            notes.removeLast(line.count)
            if notes.hasSuffix("\n") { notes.removeLast() }
            task.notes = notes.isEmpty ? nil : notes
        }
        session.pausedSeconds += max(0, Int(now.timeIntervalSince(endedAt)))
        session.endedAt = nil
        session.outcome = SessionOutcome.running.rawValue
        session.actualSeconds = 0
        if let window = session.habitWindow {
            HabitSessions.recompute(window, on: CalendarDate(storedDate: session.day), now: now, context: context)
        }
    }

    // MARK: The settle sheet

    /// Settles the running session with a choice. A task's: *Done*, *Stop for now*, *Defer to tomorrow*
    /// (a normal deferral with its count and record) or *Drop*. A habit's: *Log it* or *Stop for now*.
    /// The time is logged whichever is chosen.
    @MainActor
    public static func settle(_ session: WorkSession, as choice: SettleChoice, now: Date, boundary: DayBoundary, context: ModelContext) throws {
        if session.habitWindow != nil {
            switch choice {
            case .logIt, .done: try finish(session, as: .done, note: nil, now: now, boundary: boundary, context: context)
            case .stopForNow: try finish(session, as: .stopForNow, note: nil, now: now, boundary: boundary, context: context)
            case .deferToTomorrow, .drop: throw FocusSessionError.notForAHabit
            }
            return
        }
        guard let task = session.task else { throw FocusSessionError.notRunning }
        let today = boundary.logicalDate(at: now)
        switch choice {
        case .logIt:
            throw FocusSessionError.notForATask
        case .done:
            try finish(session, as: .done, note: nil, now: now, boundary: boundary, context: context)
        case .stopForNow:
            try finish(session, as: .stopForNow, note: nil, now: now, boundary: boundary, context: context)
        case .deferToTomorrow:
            guard session.endedAt == nil else { throw FocusSessionError.notRunning }
            close(session, at: now, as: .deferred)
            _ = try TaskDeferral.defer(task, from: today, to: today.addingDays(1), reason: .unspecified, now: now, boundary: boundary, context: context)
        case .drop:
            guard session.endedAt == nil else { throw FocusSessionError.notRunning }
            close(session, at: now, as: .dropped)
            TaskActions.drop(task, now: now, boundary: boundary, context: context)
        }
    }

    /// Closes a task's live session with the outcome matching how the task was resolved (done →
    /// `finished`, deferred → `deferred`, dropped → `dropped`), logging the time. Does nothing if there
    /// is none. Called when a task is resolved from Today or its detail while it is being timed.
    static func closeLive(of task: TaskItem, as outcome: SessionOutcome, now: Date) {
        for session in task.sessions ?? [] where session.outcome == SessionOutcome.running.rawValue && session.endedAt == nil {
            close(session, at: now, as: outcome)
        }
    }

    // MARK: Pick it back up and the chip's edge

    /// A session auto-closed at the rollover leaves one row on the next day's list offering to pick
    /// the task back up. It goes once the task is completed, dropped, moved later, or timed again,
    /// and a day later.
    public static func pickUpRows(tasks: [TaskItem], today: CalendarDate, boundary: DayBoundary) -> [PickUpRow] {
        var rows: [PickUpRow] = []
        for task in tasks where !task.isCompleted && task.droppedAt == nil {
            if let due = task.dueDate, CalendarDate(storedDate: due) > today { continue }
            let sessions = task.sessions ?? []
            guard let closed = sessions
                .filter({ $0.outcome == SessionOutcome.autoClosed.rawValue && $0.endedAt.map(boundary.logicalDate(at:)) == today })
                .max(by: { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }),
                  let endedAt = closed.endedAt else { continue }
            if sessions.contains(where: { $0.startedAt >= endedAt }) { continue }
            rows.append(PickUpRow(task: task, session: closed))
        }
        return rows.sorted { ($0.session.endedAt ?? .distantPast, $0.task.id.uuidString) < ($1.session.endedAt ?? .distantPast, $1.task.id.uuidString) }
    }

    /// The one Anchor line for the chip: an open, still-pending Anchor **closing soon** ("Asr closes in
    /// 10 min") outranks a **fixed** Anchor whose window **opens** within 30 minutes ("Maghrib in
    /// 12 min"). Flexible Anchors never appear.
    public static func approachingEdge(anchors: [Anchor], now: Date) -> ApproachingEdge? {
        let candidates = anchors.filter { anchor in
            anchor.status == .pending && anchor.rule?.placementKind != .flexible && anchor.rule?.isAfterLast != true
        }
        func minutes(_ seconds: TimeInterval) -> Int { Int((seconds / 60).rounded(.up)) }

        let closing = candidates
            .filter { AnchorAttendance.windowState(of: $0, at: now) == .closingSoon }
            .min { $0.windowEnd < $1.windowEnd }
        if let closing {
            return ApproachingEdge(title: closing.title, minutes: minutes(closing.windowEnd.timeIntervalSince(now)), kind: .closing)
        }
        let opening = candidates
            .filter { AnchorAttendance.windowState(of: $0, at: now) == .upcoming && $0.windowStart.timeIntervalSince(now) <= Double(openingLeadMinutes) * 60 }
            .min { $0.windowStart < $1.windowStart }
        if let opening {
            return ApproachingEdge(title: opening.title, minutes: minutes(opening.windowStart.timeIntervalSince(now)), kind: .opening)
        }
        return nil
    }

    // MARK: Habit minutes added by hand

    /// Adds minutes to a habit window's day by hand: stored as a finished `manual` session with no
    /// timing of its own, so everything that feeds the entry is a session and can be recomputed.
    @MainActor
    @discardableResult
    public static func addMinutes(_ minutes: Int, to window: HabitTimeWindow, on day: CalendarDate, now: Date, context: ModelContext) -> WorkSession {
        let session = WorkSession()
        session.startedAt = now
        session.day = day.storedDate
        session.outcome = SessionOutcome.manual.rawValue
        session.actualSeconds = max(0, minutes) * 60
        context.insert(session)
        session.habitWindow = window
        HabitSessions.recompute(window, on: day, now: now, context: context)
        return session
    }

    // MARK: Helpers

    /// Closes a session at `end`: folds in a pause in progress and stores elapsed minus pauses.
    static func close(_ session: WorkSession, at end: Date, as outcome: SessionOutcome) {
        let stop = max(end, session.startedAt)
        if let pausedAt = session.pausedAt {
            session.pausedSeconds += max(0, Int(stop.timeIntervalSince(pausedAt)))
            session.pausedAt = nil
        }
        session.actualSeconds = max(0, Int(stop.timeIntervalSince(session.startedAt)) - session.pausedSeconds)
        session.endedAt = stop
        session.outcome = outcome.rawValue
    }

    /// Appends `"yyyy-MM-dd HH:mm — note"` to the task's note; returns the line, or `nil` for a blank note.
    private static func append(note: String?, to task: TaskItem, now: Date, boundary: DayBoundary) -> String? {
        guard let text = note?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = boundary.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let line = "\(formatter.string(from: now)) — \(text)"
        if let existing = task.notes, !existing.isEmpty { task.notes = existing + "\n" + line } else { task.notes = line }
        return line
    }
}

/// A timed habit's minutes for a day, recomputed from its sessions (docs/schema/habit.md, "Timed habits").
public enum HabitSessions {

    /// Sets the day's entry from the window's sessions that day: `round(total seconds ÷ 60)` over all
    /// of them — never per session — so nothing drifts and two devices converge by summing rows. The
    /// entry is created (with a snapshot of the target) when there is time to record, and
    /// `completedAt` is set when the target is reached and cleared if it no longer is.
    @MainActor
    static func recompute(_ window: HabitTimeWindow, on day: CalendarDate, now: Date, context: ModelContext) {
        let seconds = (window.sessions ?? [])
            .filter { CalendarDate(storedDate: $0.day) == day && $0.outcome != SessionOutcome.running.rawValue }
            .reduce(0) { $0 + $1.actualSeconds }
        let minutes = Int((Double(seconds) / 60).rounded())

        var entry = (window.entries ?? []).filter { CalendarDate(storedDate: $0.date) == day }.max { $0.amount < $1.amount }
        if entry == nil {
            guard minutes > 0 else { return }
            let created = HabitEntry()
            created.date = day.storedDate
            created.target = window.target
            context.insert(created)
            created.window = window
            entry = created
        }
        guard let entry else { return }
        entry.amount = minutes
        if minutes >= max(1, entry.target) {
            if entry.completedAt == nil { entry.completedAt = now }
        } else {
            entry.completedAt = nil
        }
    }
}
