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
    @Environment(\.requireAccess) private var requireAccess
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(FocusCoordinator.self) private var focus

    let task: TaskItem
    /// In the panel beside the list (regular width) it closes by clearing the selection instead of dismissing a sheet.
    var embedded = false
    var onClose: () -> Void = {}
    @State private var deferring = false
    @State private var confirmingDrop = false
    @State private var editingNote = false

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }
    private var today: CalendarDate { boundary.logicalDate(at: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                    heading
                    if embedded {
                        // The panel is wide: the note beside the facts, as drawn for iPad.
                        HStack(alignment: .top, spacing: ThreadsSpace.section) {
                            note.frame(maxWidth: .infinity, alignment: .leading)
                            table.frame(width: 200)
                        }
                    } else {
                        note
                        table
                    }
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
        .fullScreenCover(isPresented: $editingNote) { NoteEditorScreen(task: task) }
        .sheet(isPresented: $deferring) {
            DeferSheet(task: task, today: today) { close() }
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
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            if !items.isEmpty {
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
            Button { if requireAccess(.editTask) { editingNote = true } } label: {
                Text(items.isEmpty ? "Add a note" : "Edit note").threadsType(.row).foregroundStyle(threads.ink)
                    .frame(maxWidth: .infinity, minHeight: ThreadsHit.minimum, alignment: items.isEmpty || embedded ? .leading : .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("editNote")
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
        Group {
            if embedded {
                // One row: Begin takes the room, the rest hug their titles.
                HStack(spacing: ThreadsSpace.tight) {
                    if !task.isCompleted { beginButton.frame(minWidth: 130) }
                    markDoneButton
                    if !task.isCompleted { deferButton; dropButton }
                }
            } else {
                VStack(spacing: ThreadsSpace.tight) {
                    if !task.isCompleted { beginButton }
                    HStack(spacing: ThreadsSpace.tight) {
                        markDoneButton
                        if !task.isCompleted { deferButton; dropButton }
                    }
                }
            }
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.vertical, ThreadsSpace.tight)
        .background(threads.app)
    }

    private var beginButton: some View {
        Button(action: begin) {
            Label(isTimingThis ? "Open timer" : "Begin", systemImage: "play").threadsType(.row).foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("beginButton")
    }

    private var markDoneButton: some View {
        PillButton(title: task.isCompleted ? "Mark not done" : "Mark done", fills: !embedded) { toggleDone() }
            .accessibilityIdentifier("markDone")
    }

    private var deferButton: some View {
        PillButton(title: "Defer", fills: !embedded) { startDefer() }
            .accessibilityIdentifier("deferButton")
    }

    private var dropButton: some View {
        Button { if requireAccess(.dropTask) { confirmingDrop = true } } label: {
            Text("Drop").threadsType(.row).foregroundStyle(threads.alert)
                .lineLimit(1)
                .padding(.vertical, 12)
                .padding(.horizontal, embedded ? 22 : 0)
                .frame(maxWidth: embedded ? nil : .infinity, minHeight: ThreadsHit.minimum)
                .background(Capsule().fill(threads.alertSoft))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dropButton")
    }

    // MARK: Actions

    private var isTimingThis: Bool { FocusSessions.liveSession(in: context)?.task === task }

    /// Begin starts a session (or, if this task is already being timed, opens the timer). A second Begin while
    /// another task is running raises the settle sheet instead.
    private func close() { embedded ? onClose() : dismiss() }

    private func begin() {
        if isTimingThis {
            focus.isShowingFocus = true
            close()
        } else if FocusSessions.liveSession(in: context) == nil {
            focus.begin(.task(task))
            close()
        } else {
            // The settle sheet is presented from the shell, so let this sheet finish dismissing first: two
            // presentations at once leave the second one unresponsive.
            close()
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
        close()
    }

    /// The first and second deferral move the task to tomorrow at once; from the third the picker opens.
    private func startDefer() {
        guard requireAccess(.deferTask) else { return }
        let preview = TaskDeferral.preview(task, from: today)
        if preview.requiresPicker {
            deferring = true
        } else {
            _ = try? TaskDeferral.defer(task, from: today, to: today.addingDays(1), reason: .unspecified, now: .now, boundary: boundary, context: context)
            close()
        }
    }

    private func drop() {
        guard requireAccess(.dropTask) else { return }
        TaskActions.drop(task, now: .now, boundary: boundary, context: context)
        close()
    }

    private func stopRepeating() {
        guard requireAccess(.editTask) else { return }
        TaskActions.stopRepeating(task)
        close()
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
