//
//  HabitFormScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// "What kind of habit?" (HB-03), then the form. One sheet with its own navigation, so there is only ever one
/// presentation. The kind can't change later, because the history is read by it.
struct AddHabitFlow: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                    Text("What kind of habit?").threadsType(.display(.compact)).foregroundStyle(threads.ink)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        Divider().overlay(threads.line)
                        ForEach([HabitKind.binary, .counted, .timed, .avoid], id: \.self) { kind in
                            NavigationLink {
                                HabitFormScreen(draft: HabitDraft(kind: kind), onFinished: { dismiss() })
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                                        Text(HabitForm.question(kind)).threadsType(.row).foregroundStyle(threads.ink)
                                        Text(HabitForm.hint(kind)).threadsType(.meta).foregroundStyle(threads.ink2).multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(threads.ink3)
                                }
                                .padding(.vertical, ThreadsSpace.row)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("kind-\(kind.rawValue)")
                            Divider().overlay(threads.line)
                        }
                    }
                    VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                        Text("Or start from").threadsType(.label).foregroundStyle(threads.ink2)
                        FlowChips {
                            ForEach([HabitPreset.quran, .dhikr, .exercise, .running], id: \.self) { preset in
                                let draft = HabitDraft.preset(preset)
                                NavigationLink {
                                    HabitFormScreen(draft: draft, onFinished: { dismiss() })
                                } label: {
                                    Text(draft.title).threadsType(.body).foregroundStyle(threads.ink2)
                                        .padding(ThreadsSpace.chipPadding).frame(minHeight: ThreadsHit.minimum)
                                        .overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("preset-\(preset.rawValue)")
                            }
                        }
                    }
                    Text("The kind can't change later, because the history is read by it.")
                        .threadsType(.meta).foregroundStyle(threads.ink2)
                }
                .padding(.horizontal, ThreadsSpace.gutter)
                .padding(.top, ThreadsSpace.section)
            }
            .background(threads.app)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// The habit form (HB-03/04/07): a name, the kind's target, times of day, a schedule, a group and a note. The same
/// form edits a habit, with the kind fixed.
struct HabitFormScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HabitGroup.sortOrder) private var allGroups: [HabitGroup]

    private let habit: Habit?
    private let onFinished: () -> Void
    @State private var form: HabitForm
    @State private var message: String?
    @State private var editingWindow: Int?
    /// A group typed in the form is only made when the habit is saved, so cancelling leaves nothing behind.
    @State private var pendingGroup: String?
    @State private var namingGroup = false

    /// A new habit from a draft (a kind, or a preset).
    init(draft: HabitDraft, onFinished: @escaping () -> Void = {}) {
        habit = nil
        self.onFinished = onFinished
        _form = State(initialValue: HabitForm(draft: draft))
    }

    /// An existing habit: the kind is fixed.
    init(editing habit: Habit, onFinished: @escaping () -> Void = {}) {
        self.habit = habit
        self.onFinished = onFinished
        _form = State(initialValue: HabitForm(draft: HabitDraft(editing: habit)))
    }

    private var groups: [HabitGroup] { allGroups.filter { !$0.isArchived } }
    private var windowsWithHistory: Set<UUID> {
        Set((habit?.windows ?? []).filter { !($0.entries ?? []).isEmpty }.map(\.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                TextField("What is it called?", text: $form.draft.title)
                    .threadsType(.lede)
                    .padding(.bottom, ThreadsSpace.tight)
                    .overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                    .accessibilityLabel("Name")
                    .accessibilityIdentifier("habitName")
                VStack(spacing: 0) {
                    row("Kind", habit == nil ? HabitForm.kindName(form.draft.kind) : "\(HabitForm.kindName(form.draft.kind)) · fixed")
                    if let title = HabitForm.targetTitle(kind: form.draft.kind, target: form.draft.windows.first?.target ?? 1) {
                        stepperRow("Target", title)
                    }
                }
                timesOfDay
                schedule
                VStack(spacing: 0) {
                    groupRow
                    VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                        Text("Note").threadsType(.lede).foregroundStyle(threads.ink2)
                        TextField("Optional", text: Binding(get: { form.draft.notes ?? "" }, set: { form.draft.notes = $0 }), axis: .vertical)
                            .threadsType(.lede).foregroundStyle(threads.ink)
                    }
                    .padding(.vertical, ThreadsSpace.row)
                    Divider().overlay(threads.line)
                }
                if let message {
                    Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("habitFormMessage")
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.row)
            .padding(.bottom, 60)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(threads.app)
        .navigationTitle(habit == nil ? "New habit" : "Edit habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if habit != nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("saveHabit") }
        }
        .sheet(item: Binding(get: { editingWindow.map(WindowRef.init) }, set: { editingWindow = $0?.index })) { ref in
            WindowEditorSheet(form: $form, index: ref.index, canRemove: form.canRemoveWindow(at: ref.index, withHistory: windowsWithHistory))
        }
    }

    private struct WindowRef: Identifiable { var index: Int; var id: Int { index } }

    // MARK: Sections

    private var timesOfDay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Times of day").threadsType(.label).foregroundStyle(threads.ink2).padding(.bottom, ThreadsSpace.tight)
            Divider().overlay(threads.line)
            ForEach(Array(form.draft.windows.enumerated()), id: \.offset) { index, window in
                Button { editingWindow = index } label: {
                    HStack {
                        Text(window.label.isEmpty ? "Any time" : window.label).threadsType(.lede).foregroundStyle(threads.ink)
                        Spacer(minLength: ThreadsSpace.tight)
                        Text(HabitForm.summary(window)).threadsType(.body).foregroundStyle(threads.ink2)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
                    }
                    .frame(minHeight: 56).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("window-\(index)")
                Divider().overlay(threads.line)
            }
            if form.canAddWindow {
                Button { form.addWindow() } label: {
                    HStack {
                        Label("Add another time", systemImage: "plus").threadsType(.lede).foregroundStyle(threads.ink)
                        Spacer()
                        Text("up to \(HabitEditing.maxWindows)").threadsType(.body).foregroundStyle(threads.ink2)
                    }
                    .frame(minHeight: 52).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addWindow")
                Divider().overlay(threads.line)
            }
        }
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text("Schedule").threadsType(.label).foregroundStyle(threads.ink2)
            FlowChips {
                Chip(title: "Every day", isSelected: form.schedule == .everyDay) { form.setSchedule(.everyDay) }
                Chip(title: "Weekdays", isSelected: form.schedule == .weekdays) { form.setSchedule(.weekdays) }
                Chip(title: "Pick days", isSelected: { if case .days = form.schedule { true } else { false } }()) {
                    form.setSchedule(.days(form.draft.weekdays.count == 7 ? [1, 3, 5] : form.draft.weekdays))
                }
                .accessibilityIdentifier("schedulePick")
                Chip(title: "N a week", isSelected: { if case .perWeek = form.schedule { true } else { false } }()) {
                    form.setSchedule(.perWeek(max(1, form.draft.perWeek == 0 ? 3 : form.draft.perWeek)))
                }
                .accessibilityIdentifier("scheduleWeekly")
            }
            if case .days(let days) = form.schedule {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        Button { form.toggleDay(day) } label: {
                            Text(["M", "T", "W", "T", "F", "S", "S"][day - 1]).threadsType(.row)
                                .foregroundStyle(days.contains(day) ? threads.ink : threads.ink2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Circle().fill(days.contains(day) ? threads.card : .clear))
                                .overlay(Circle().strokeBorder(days.contains(day) ? threads.ink : threads.line2, lineWidth: days.contains(day) ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day - 1])
                        .accessibilityAddTraits(days.contains(day) ? .isSelected : [])
                    }
                }
            }
            if case .perWeek(let n) = form.schedule {
                Stepper(value: Binding(get: { n }, set: { form.setSchedule(.perWeek($0)) }), in: 1...7) {
                    Text(n == 1 ? "Once a week, any day" : "\(n) times a week, any days").threadsType(.lede).foregroundStyle(threads.ink)
                }
            }
        }
    }

    /// Chips rather than a menu: None, each group, and a new one typed here (made only when the habit is saved).
    private var groupRow: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text("Group").threadsType(.label).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.row)
            FlowChips {
                Chip(title: "None", isSelected: form.draft.group == nil && !namingGroup) {
                    form.draft.group = nil; namingGroup = false
                }
                ForEach(groups, id: \.id) { group in
                    Chip(title: group.title, isSelected: form.draft.group?.id == group.id && !namingGroup) {
                        form.draft.group = group; namingGroup = false
                    }
                }
                Chip(title: "New group…", isSelected: namingGroup) { namingGroup = true; form.draft.group = nil }
                    .accessibilityIdentifier("newGroupChip")
            }
            if namingGroup {
                TextField("Group name", text: Binding(get: { pendingGroup ?? "" }, set: { pendingGroup = $0 }))
                    .threadsType(.lede).padding(.bottom, ThreadsSpace.tight)
                    .overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                    .accessibilityIdentifier("newGroupName")
            }
            Divider().overlay(threads.line).padding(.top, ThreadsSpace.tight)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Text(value).threadsType(.lede).foregroundStyle(threads.ink)
            }
            .padding(.vertical, ThreadsSpace.row)
            Divider().overlay(threads.line)
        }
        .accessibilityElement(children: .combine)
    }

    private func stepperRow(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Text(value).threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("targetValue")
                StepperPill(title: "target", canDecrement: true, onDecrement: { form.stepTarget(by: -1) }, onIncrement: { form.stepTarget(by: 1) })
                    .scaleEffect(0.85)
            }
            .padding(.vertical, ThreadsSpace.tight)
            Divider().overlay(threads.line)
        }
    }

    // MARK: Save

    private func save() {
        do {
            var draft = form.draft
            if namingGroup, let name = pendingGroup, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.group = try HabitEditing.createGroup(named: name, in: context)
            }
            if let habit { try HabitEditing.update(habit, with: draft, in: context) }
            else { try HabitEditing.create(draft, in: context, now: .now) }
            onFinished()
            dismiss()
        } catch let error as HabitEditError {
            message = HabitForm.message(for: error)
        } catch {
            message = "That couldn't be saved. Try again."
        }
    }
}

/// One time of day (HB-03): its name, its hours (or all day) and an optional reminder.
struct WindowEditorSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    @Binding var form: HabitForm
    let index: Int
    let canRemove: Bool

    private var window: HabitWindowDraft { form.draft.windows[index] }
    private var isAllDay: Bool { window.startMinute == 0 && window.endMinute == 1439 }

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            Text("Time of day").threadsType(.display(.compact)).foregroundStyle(threads.ink)
            TextField("Name (Morning, Evening…)", text: Binding(get: { window.label }, set: { form.draft.windows[index].label = $0 }))
                .threadsType(.lede)
                .padding(.bottom, ThreadsSpace.tight)
                .overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                .accessibilityIdentifier("windowName")
            Toggle("All day", isOn: Binding(
                get: { isAllDay },
                set: { on in
                    form.draft.windows[index].startMinute = on ? 0 : 6 * 60
                    form.draft.windows[index].endMinute = on ? 1439 : 12 * 60
                }))
            if !isAllDay {
                DatePicker("From", selection: Binding(
                    get: { HabitForm.date(forMinute: window.startMinute) },
                    set: { form.draft.windows[index].startMinute = HabitForm.minute(of: $0) }), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: Binding(
                    get: { HabitForm.date(forMinute: window.endMinute) },
                    set: { form.draft.windows[index].endMinute = HabitForm.minute(of: $0) }), displayedComponents: .hourAndMinute)
            }
            Toggle("Remind me", isOn: Binding(
                get: { window.reminderMinute != nil },
                set: { form.draft.windows[index].reminderMinute = $0 ? (isAllDay ? 9 * 60 : window.startMinute) : nil }))
            if let reminder = window.reminderMinute {
                DatePicker("At", selection: Binding(
                    get: { HabitForm.date(forMinute: reminder) },
                    set: { form.draft.windows[index].reminderMinute = HabitForm.minute(of: $0) }), displayedComponents: .hourAndMinute)
            }
            Spacer()
            if canRemove {
                Button(role: .destructive) { form.removeWindow(at: index); dismiss() } label: {
                    Text("Remove this time").threadsType(.row).foregroundStyle(threads.alert)
                        .frame(maxWidth: .infinity, minHeight: 52).background(Capsule().fill(threads.alertSoft))
                }
                .buttonStyle(.plain)
            }
            Button { dismiss() } label: {
                Text("Done").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("windowDone")
        }
        .padding(ThreadsSpace.gutter)
        .background(threads.app)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
