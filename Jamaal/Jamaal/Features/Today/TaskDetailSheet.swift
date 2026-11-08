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
    @Environment(EditUndoCenter.self) private var editUndo
    @Query(sort: \TaskCategory.sortOrder) private var allCategories: [TaskCategory]

    let task: TaskItem
    /// In the panel beside the list (regular width) it closes by clearing the selection instead of dismissing a sheet.
    var embedded = false
    var onClose: () -> Void = {}
    @State private var deferring = false
    @State private var confirmingDrop = false
    @State private var editingNote = false
    // Editing in place: there is no edit mode, so a visit's changes are kept as one undo group (EditUndoCenter).
    @State private var snapshot: TaskSnapshot?
    /// The visit ended in Mark done, Defer, Drop or Begin: those are not edits, so there is nothing to undo as one.
    @State private var resolved = false
    @State private var titleText = ""
    @SwiftUI.FocusState private var titleFocused: Bool
    @State private var picking: EditField?
    @State private var showsSaved = false
    @State private var dayFull: DayFullCheck?

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }
    private var today: CalendarDate { boundary.logicalDate(at: .now) }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// The pane's own width. The note sits beside a 200 pt table only in a pane wide enough for both (an iPad's); in half of an iPhone
    /// Duo's inner display the two stack, as they do on a phone.
    @State private var paneWidth: CGFloat = 0
    private var sideBySide: Bool { embedded && paneWidth >= 560 }

    var body: some View {
        // On a phone the field pickers push inside the sheet; beside the list (regular width) they are popovers on their rows.
        Group {
            if embedded {
                content
            } else {
                NavigationStack {
                    content
                        .navigationDestination(item: $picking) { field in
                            pickerView(for: field, showsBack: true)
                        }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            snapshot = TaskEditing.snapshot(task)
            titleText = task.title
        }
        .onDisappear { endVisit() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                    header
                    heading
                    if sideBySide {
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
            if let check = dayFull { dayFullPanel(check).padding(.horizontal, ThreadsSpace.gutter) }
            actions
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { paneWidth = $0 }
        .background(threads.app)
        .hidesNavigationBar()
        .onAppear {
            #if DEBUG
            if DebugLaunch.openDefer { deferring = true }
            #endif
        }
        .fullScreenCoverOrSheet(isPresented: $editingNote) { NoteEditorScreen(task: task) }
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

    /// The header: `Saved` once something has been changed, and ⋯ for what isn't one of the four actions beneath.
    private var header: some View {
        HStack {
            if showsSaved {
                Label(TaskEditCopy.savedLabel, systemImage: "checkmark").labelStyle(.titleAndIcon)
                    .threadsType(.label).foregroundStyle(threads.accent)
                    .accessibilityIdentifier("savedTick")
            }
            Spacer()
            moreMenu
        }
        .frame(minHeight: ThreadsHit.minimum)
    }

    private var moreMenu: some View {
        Menu {
            Button(TaskNotes.items(task.notes).isEmpty ? "Add a note" : "Edit note", systemImage: "square.and.pencil") {
                if requireAccess(.editTask) { editingNote = true }
            }
            .accessibilityIdentifier("moreEditNote")
            if !task.isCompleted {
                Button("Move to another day", systemImage: "calendar") { if requireAccess(.editTask) { picking = .due } }
                    .accessibilityIdentifier("moreMoveDay")
            }
            if task.repeatMode != .off && !task.isCompleted {
                Button("Stop repeating", systemImage: "repeat") { stopRepeating() }
                    .accessibilityIdentifier("moreStopRepeating")
            }
        } label: {
            Label("More", systemImage: "ellipsis").labelStyle(.iconOnly)
                .frame(width: ThreadsHit.minimum, height: ThreadsHit.minimum).contentShape(Rectangle())
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("moreMenu")
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
            // The title reads as editable (a faint tinted box) and edits where it stands; Return or leaving it saves, and an empty one reverts.
            TextField("Title", text: $titleText, axis: .vertical)
                .threadsType(.display(.compact)).foregroundStyle(threads.ink)
                .focused($titleFocused)
                .submitLabel(.done)
                .disabled(task.isCompleted)
                .padding(.horizontal, ThreadsSpace.row).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(titleFocused ? threads.card : threads.accent.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(titleFocused ? threads.accent : .clear, lineWidth: 1.5))
                .padding(.horizontal, -ThreadsSpace.row)
                .accessibilityIdentifier("detailTitle")
                .onSubmit { commitTitle() }
                .onChange(of: titleText) { _, new in
                    if new.contains("\n") { titleText = new.replacingOccurrences(of: "\n", with: ""); commitTitle(); titleFocused = false }
                }
                .onChange(of: titleFocused) { _, focused in if !focused { commitTitle() } }
        }
    }

    private func commitTitle() {
        guard titleText != task.title else { return }
        if requireAccess(.editTask), TaskEditing.setTitle(task, titleText) {
            titleText = task.title
            markSaved()
        } else {
            titleText = task.title
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
            editRow(.category, task.category.map(\.name) ?? "None")
            editRow(.effort, TaskDetailCopy.effort(task.effortMinutes))
            editRow(.matters, TaskDetailCopy.matters(task.importanceLevel))
            editRow(.due, TaskDetailCopy.due(task.dueDate.map(CalendarDate.init(storedDate:)), today: today))
            editRow(.repeats, TaskDetailCopy.repeatName(task.repeatMode))
            historyRow
            if isFuture, let due = task.dueDate.map(CalendarDate.init(storedDate:)) {
                Text(TaskEditCopy.futureNote(for: due)).threadsType(.meta).foregroundStyle(threads.ink2)
                    .padding(.top, ThreadsSpace.row)
                    .accessibilityIdentifier("futureNote")
            }
        }
    }

    /// A field you can change where it stands: the whole row opens its picker.
    private func editRow(_ field: EditField, _ value: String) -> some View {
        Button { if !task.isCompleted, requireAccess(.editTask) { picking = field } } label: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(field.title).threadsType(.lede).foregroundStyle(threads.ink2)
                    Spacer(minLength: ThreadsSpace.row)
                    Text(value).threadsType(.lede).foregroundStyle(threads.ink).multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
                }
                .padding(.vertical, ThreadsSpace.row)
                .frame(minHeight: ThreadsHit.minimum)
                Divider().overlay(threads.line)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Changes it")
        .accessibilityIdentifier("detailRow-\(field.title)")
        .popover(isPresented: Binding(get: { embedded && picking == field }, set: { if !$0, picking == field { picking = nil } })) {
            pickerView(for: field, showsBack: false).frame(minWidth: 320, minHeight: 360)
        }
    }

    private var historyRow: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("History").threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer(minLength: ThreadsSpace.row)
                Text(TaskDetailCopy.history(deferrals: task.deferralCount, addedOn: boundary.logicalDate(at: task.createdAt)))
                    .threadsType(.lede).foregroundStyle(threads.ink).multilineTextAlignment(.trailing)
            }
            .padding(.vertical, ThreadsSpace.row)
            Divider().overlay(threads.line)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func pickerView(for field: EditField, showsBack: Bool) -> some View {
        let close = { picking = nil }
        switch field {
        case .category:
            CategoryPicker(task: task, showsBack: showsBack, categories: allCategories.filter { !$0.isArchived }, onChoose: { TaskEditing.setCategory(task, $0); markSaved(); close() }, onBack: close)
        case .effort:
            EffortPicker(task: task, showsBack: showsBack, onChoose: { TaskEditing.setEffort(task, minutes: $0); markSaved(); close() },
                         onStep: { TaskEditing.setEffort(task, minutes: $0); markSaved() }, onBack: close)
        case .matters:
            MattersPicker(task: task, showsBack: showsBack, onChoose: { TaskRules.setImportance(task, to: $0, defaultDueDate: today); markSaved(); close() }, onBack: close)
        case .due:
            DuePicker(task: task, today: today, firstWeekdayISO: firstWeekdayISO, showsBack: showsBack, onChoose: { setDue($0); close() }, onBack: close)
        case .repeats:
            RepeatPicker(task: task, showsBack: showsBack, onChoose: { TaskEditing.setRepeat(task, $0, today: today); markSaved(); close() }, onBack: close)
        }
    }

    private var firstWeekdayISO: Int { ((Calendar.current.firstWeekday + 5) % 7) + 1 }

    /// Choosing a date saves it. Choosing today is *Move to today*, so it goes through the day-is-full check too.
    private func setDue(_ date: CalendarDate?) {
        if date == today { requestMoveToToday(); return }
        guard (try? TaskRules.setDueDate(task, to: date)) != nil else { return }
        markSaved()
    }

    private func markSaved() {
        withAnimation(.snappy) { showsSaved = true }
        resolved = false
    }

    // MARK: A visit

    /// Leaving the task ends the visit: one undo toast for everything changed in it, unless it ended in Mark done, Defer, Drop or Begin.
    private func endVisit() {
        commitTitle()
        guard let snapshot, !resolved else { return }
        editUndo.visitEnded(task: task, snapshot: snapshot)
        self.snapshot = nil
    }

    private var isFuture: Bool {
        task.dueDate.map { CalendarDate(storedDate: $0) > today } ?? false
    }

    // MARK: Move to today

    private var moveToTodayButton: some View {
        Button(action: requestMoveToToday) {
            Label(TaskEditCopy.moveToToday, systemImage: "arrow.down").threadsType(.row).foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("moveToToday")
    }

    /// Moves the task to today (it then counts against today's capacity). A full day offers another day first, as Add does.
    private func requestMoveToToday() {
        guard requireAccess(.editTask) else { return }
        if let check = try? TaskCreation.dayFullCheck(adding: task.effortMinutes, on: today, in: context, now: .now) {
            withAnimation(.snappy) { dayFull = check }
        } else {
            moveToToday()
        }
    }

    private func moveToToday() {
        dayFull = nil
        guard (try? TaskEditing.moveToToday(task, today: today)) != nil else { return }
        markSaved()
    }

    private func dayFullPanel(_ check: DayFullCheck) -> some View {
        let copy = AddTaskForm.dayFullCopy(check, adding: task.effortMinutes ?? 0, on: today, today: today)
        return VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text(copy.title).threadsType(.lede).foregroundStyle(threads.ink)
            Text(copy.detail).threadsType(.meta).foregroundStyle(threads.ink2)
            HStack(spacing: ThreadsSpace.tight) {
                if let suggestion = check.suggestion {
                    Button {
                        dayFull = nil
                        try? TaskRules.setDueDate(task, to: suggestion)
                        markSaved()
                    } label: {
                        Text(AddTaskForm.relativeButton(suggestion, today: today)).threadsType(.row).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52).background(Capsule().fill(threads.terra))
                    }
                    .accessibilityIdentifier("dayFullOffer")
                }
                Button { moveToToday() } label: {
                    Text("Move anyway").threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 52).overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                }
                .accessibilityIdentifier("moveAnyway")
            }
            .buttonStyle(.plain)
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(threads.line2, lineWidth: 1))
        .padding(.vertical, ThreadsSpace.tight)
    }

    private var actions: some View {
        Group {
            if embedded || verticalSizeClass == .compact {
                // One row (also on a phone held sideways, where two rows would take a third of the height): Begin takes the room, the rest
                // hug their titles. In a narrow pane (half of an iPhone Duo's inner display) the row would be wider than the pane and
                // widen everything above it, so it stacks instead (#329).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ThreadsSpace.tight) {
                        if !task.isCompleted { primaryButton.frame(minWidth: 130) }
                        markDoneButton
                        if !task.isCompleted { deferButton; dropButton }
                    }
                    stackedActions
                }
            } else {
                stackedActions
            }
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.vertical, ThreadsSpace.tight)
        .background(threads.app)
    }

    private var stackedActions: some View {
        VStack(spacing: ThreadsSpace.tight) {
            if !task.isCompleted { primaryButton }
            HStack(spacing: ThreadsSpace.tight) {
                markDoneButton
                if !task.isCompleted { deferButton; dropButton }
            }
        }
    }

    /// A future task's primary is *Move to today*, which replaces Begin: it isn't actionable until its day.
    @ViewBuilder private var primaryButton: some View {
        if isFuture { moveToTodayButton } else { beginButton }
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
        resolved = true
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
        resolved = true
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
        resolved = true
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
        resolved = true
        TaskActions.drop(task, now: .now, boundary: boundary, context: context)
        close()
    }

    private func stopRepeating() {
        guard requireAccess(.editTask) else { return }
        resolved = true
        TaskActions.stopRepeating(task)
        close()
    }

    private static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
    }

}

/// The note's checkbox: a rounded square, filled accent with a check when done.
struct CheckSquare: View {
    @Environment(\.threads) private var threads
    let isDone: Bool
    /// How far the middle of a line of text sits above its baseline (half the height of its capitals), at the default text size.
    @ScaledMetric(relativeTo: .body) private var textMiddle: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .strokeBorder(isDone ? threads.accent : threads.deep, lineWidth: 1.5)
            .background(RoundedRectangle(cornerRadius: 7).fill(isDone ? threads.accent : .clear))
            .overlay {
                if isDone { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(threads.onAccent) }
            }
            .frame(width: 26, height: 26)
            // A shape has no baseline, so a row aligned on the first text baseline put the box's bottom edge there and the box sat above its
            // text. The box's baseline is now where the middle of the first line is, so the two are centred on each other (#342).
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + textMiddle }
            .accessibilityHidden(true)
    }
}
