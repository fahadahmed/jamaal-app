//
//  TaskDetailSheet.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// A task's detail (TK-02): category, title, its note as a tappable checklist, the Effort / Matters / Due / History
/// table, and Mark done, Defer, Drop (and Stop repeating). Begin arrives with the focus session; Edit note with TK-04.
struct TaskDetailSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(FocusCoordinator.self) private var focus

    let task: TaskItem
    @State private var deferring = false
    @State private var confirmingDrop = false

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }
    private var today: CalendarDate { boundary.logicalDate(at: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                    heading
                    note
                    table
                }
                .padding(.horizontal, ThreadsSpace.gutter)
                .padding(.top, ThreadsSpace.section)
            }
            actions
        }
        .background(threads.app)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            #if DEBUG
            if DebugLaunch.openDefer { deferring = true }
            #endif
        }
        .sheet(isPresented: $deferring) {
            DeferSheet(task: task, today: today) { dismiss() }
        }
        .confirmationDialog(
            task.repeatMode == .off ? "Drop this task?" : "Skip just this one?",
            isPresented: $confirmingDrop, titleVisibility: .visible
        ) {
            Button(task.repeatMode == .off ? "Drop" : "Skip this one", role: .destructive) { drop() }
            if task.repeatMode != .off { Button("Stop repeating") { stopRepeating() } }
        } message: {
            Text(task.repeatMode == .off ? "It leaves Today. Nothing else changes." : "The next one is created as usual.")
        }
    }

    // MARK: Pieces

    private var heading: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            if let category = task.category, !category.name.isEmpty {
                HStack(spacing: 8) {
                    Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 9, height: 9)
                    Text(category.name).threadsType(.body).foregroundStyle(threads.ink2)
                }
            }
            Text(task.title).threadsType(.display(.compact)).foregroundStyle(threads.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private var note: some View {
        let items = TaskNotes.items(task.notes)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: ThreadsSpace.row) {
                ForEach(items, id: \.line) { item in
                    switch item.kind {
                    case .checkbox(let isDone):
                        Button { toggle(item.line) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: ThreadsSpace.row) {
                                CheckSquare(isDone: isDone)
                                Text(Self.inline(item.text))
                                    .threadsType(.lede)
                                    .strikethrough(isDone, color: threads.ink3)
                                    .foregroundStyle(isDone ? threads.ink3 : threads.ink)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(minHeight: ThreadsHit.minimum, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(Self.inline(item.text).characters))
                        .accessibilityValue(isDone ? "Done" : "Not done")
                    case .text:
                        Text(Self.inline(item.text)).threadsType(.lede).foregroundStyle(threads.ink)
                    }
                }
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            Divider().overlay(threads.line)
            tableRow("Effort", TaskDetailCopy.effort(task.effortMinutes))
            tableRow("Matters", TaskDetailCopy.matters(task.importanceLevel))
            tableRow("Due", TaskDetailCopy.due(task.dueDate.map(CalendarDate.init(storedDate:)), today: today))
            tableRow("History", TaskDetailCopy.history(deferrals: task.deferralCount, addedOn: boundary.logicalDate(at: task.createdAt)))
            if task.repeatMode != .off { tableRow("Repeats", Self.repeatName(task.repeatMode)) }
        }
    }

    private func tableRow(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer(minLength: ThreadsSpace.row)
                Text(value).threadsType(.lede).foregroundStyle(threads.ink).multilineTextAlignment(.trailing)
            }
            .padding(.vertical, ThreadsSpace.row)
            Divider().overlay(threads.line)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: ThreadsSpace.tight) {
            if !task.isCompleted {
                Button(action: begin) {
                    Label(isTimingThis ? "Open timer" : "Begin", systemImage: "play").threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("beginButton")
            }
            HStack(spacing: ThreadsSpace.tight) {
                PillButton(title: task.isCompleted ? "Mark not done" : "Mark done", fills: true) { toggleDone() }
                    .accessibilityIdentifier("markDone")
                if !task.isCompleted {
                    PillButton(title: "Defer", fills: true) { startDefer() }
                        .accessibilityIdentifier("deferButton")
                    Button { confirmingDrop = true } label: {
                        Text("Drop").threadsType(.row).foregroundStyle(threads.alert)
                            .lineLimit(1)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: ThreadsHit.minimum)
                            .background(Capsule().fill(threads.alertSoft))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dropButton")
                }
            }
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.vertical, ThreadsSpace.tight)
        .background(threads.app)
    }

    // MARK: Actions

    private var isTimingThis: Bool { FocusSessions.liveSession(in: context)?.task === task }

    /// Begin starts a session (or, if this task is already being timed, opens the timer). A second Begin while
    /// another task is running raises the settle sheet instead.
    private func begin() {
        if isTimingThis {
            focus.isShowingFocus = true
            dismiss()
        } else if FocusSessions.liveSession(in: context) == nil {
            focus.begin(.task(task))
            dismiss()
        } else {
            // The settle sheet is presented from the shell, so let this sheet finish dismissing first: two
            // presentations at once leave the second one unresponsive.
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                focus.begin(.task(task))
            }
        }
    }

    private func toggle(_ line: Int) {
        if let updated = TaskNotes.toggled(task.notes, line: line) { task.notes = updated }
    }

    private func toggleDone() {
        if task.isCompleted {
            try? TaskActions.uncomplete(task, boundary: boundary, context: context)
        } else {
            TaskActions.complete(task, now: .now, boundary: boundary, context: context)
        }
        dismiss()
    }

    /// The first and second deferral move the task to tomorrow at once; from the third the picker opens.
    private func startDefer() {
        let preview = TaskDeferral.preview(task, from: today)
        if preview.requiresPicker {
            deferring = true
        } else {
            _ = try? TaskDeferral.defer(task, from: today, to: today.addingDays(1), reason: .unspecified, now: .now, boundary: boundary, context: context)
            dismiss()
        }
    }

    private func drop() {
        TaskActions.drop(task, now: .now, boundary: boundary, context: context)
        dismiss()
    }

    private func stopRepeating() {
        TaskActions.stopRepeating(task)
        dismiss()
    }

    private static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
    }

    private static func repeatName(_ kind: RepeatKind) -> String {
        switch kind {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .off, .unknown: "Never"
        }
    }
}

/// The note's checkbox: a rounded square, filled accent with a check when done.
struct CheckSquare: View {
    @Environment(\.threads) private var threads
    let isDone: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .strokeBorder(isDone ? threads.accent : threads.deep, lineWidth: 1.5)
            .background(RoundedRectangle(cornerRadius: 7).fill(isDone ? threads.accent : .clear))
            .overlay {
                if isDone { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(threads.onAccent) }
            }
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)
    }
}
