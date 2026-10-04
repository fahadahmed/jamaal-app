//
//  AnchorFormScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Choose a type (AN-03), then the scheduled form. One sheet with its own navigation.
struct AddAnchorRuleFlow: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                    Text("What does it follow?").threadsType(.display(.compact)).foregroundStyle(threads.ink)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        Divider().overlay(threads.line)
                        ForEach([AnchorSource.schoolRun, .binNight, .plantWatering, .custom], id: \.self) { source in
                            NavigationLink {
                                AnchorFormScreen(draft: AnchorRuleDraft.preset(source, today: today), editing: nil, onFinished: { dismiss() })
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                                        Text(AnchorsCopy.typeTitle(source)).threadsType(.row).foregroundStyle(threads.ink)
                                        Text(AnchorsCopy.typeHint(source)).threadsType(.meta).foregroundStyle(threads.ink2).multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(threads.ink3)
                                }
                                .padding(.vertical, ThreadsSpace.row).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("type-\(source.rawValue)")
                            Divider().overlay(threads.line)
                        }
                    }
                    Text("A one-off, like a dentist appointment, is added from the + on Today.").threadsType(.meta).foregroundStyle(threads.ink2)
                }
                .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.section)
            }
            .background(threads.app)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var today: CalendarDate { CalendarDate(pickerDate: .now) }
}

/// The scheduled form (AN-05): a name, how it repeats, its named times, how long it takes, fixed or flexible, when it
/// ends, reminders. The same form edits a rule (the kind of rule stays).
struct AnchorFormScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let rule: AnchorRule?
    private let onFinished: () -> Void
    @State private var form: AnchorForm
    @State private var message: String?
    @State private var editingSlot: Int?
    @State private var hasEnd: Bool

    init(draft: AnchorRuleDraft, editing rule: AnchorRule?, onFinished: @escaping () -> Void = {}) {
        self.rule = rule
        self.onFinished = onFinished
        let today = CalendarDate(pickerDate: .now)
        _form = State(initialValue: AnchorForm(draft: draft, today: today))
        _hasEnd = State(initialValue: draft.endDate != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                TextField("What is it called?", text: $form.draft.title)
                    .threadsType(.lede).padding(.bottom, ThreadsSpace.tight)
                    .overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                    .accessibilityLabel("Name").accessibilityIdentifier("anchorName")
                repeats
                times
                VStack(spacing: 0) {
                    stepperRow("Takes", form.draft.effortMinutes.map { "\($0) min" } ?? "Not set") {
                        Stepper("", value: Binding(get: { form.draft.effortMinutes ?? 0 }, set: { form.draft.effortMinutes = $0 > 0 ? $0 : nil }), in: 0...480, step: 5)
                            .labelsHidden()
                    }
                    if form.draft.repeats.isCalendarBased { placementRow }
                    endsRow
                    reminderRow
                }
                if let message {
                    Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("anchorFormMessage")
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.row).padding(.bottom, 60)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(threads.app)
        .navigationTitle(rule == nil ? "New rule" : "Edit rule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if rule != nil { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("saveAnchorRule") }
        }
        .sheet(item: Binding(get: { editingSlot.map(SlotRef.init) }, set: { editingSlot = $0?.index })) { ref in
            SlotEditorSheet(form: $form, index: ref.index)
        }
    }

    private struct SlotRef: Identifiable { var index: Int; var id: Int { index } }

    // MARK: Sections

    private var repeats: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text("Repeats").threadsType(.label).foregroundStyle(threads.ink2)
            FlowChips {
                ForEach(AnchorForm.RepeatKind.allCases, id: \.self) { kind in
                    Chip(title: AnchorForm.repeatTitle(kind), isSelected: form.repeatKind == kind) { form.chooseRepeat(kind) }
                        .accessibilityIdentifier("repeat-\(kind)")
                }
            }
            switch form.draft.repeats {
            case .days(let days):
                dayCircles(days)
            case .everyNDays(let n):
                intervalRow(n == 1 ? "Every day" : "Every \(n) days", canDecrement: n > 1)
            case .everyNWeeks(let n, let days):
                intervalRow(n == 1 ? "Every week" : "Every \(n) weeks", canDecrement: n > 1)
                dayCircles(days)
            case .afterLast(let minDays, let maxDays):
                afterLastControls(minDays: minDays, maxDays: maxDays)
            }
        }
    }

    private func intervalRow(_ text: String, canDecrement: Bool) -> some View {
        HStack {
            Text(text).threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("intervalText")
            Spacer()
            StepperPill(title: "interval", canDecrement: canDecrement, onDecrement: { form.stepInterval(by: -1) }, onIncrement: { form.stepInterval(by: 1) })
                .scaleEffect(0.85)
        }
    }

    private func dayCircles(_ days: Set<Int>) -> some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                Button { form.toggleDay(day) } label: {
                    Text(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][day - 1]).threadsType(.label)
                        .foregroundStyle(days.contains(day) ? threads.ink : threads.ink2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Circle().fill(days.contains(day) ? threads.card : .clear))
                        .overlay(Circle().strokeBorder(days.contains(day) ? threads.ink : threads.line2, lineWidth: days.contains(day) ? 1.5 : 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day - 1])
                .accessibilityAddTraits(days.contains(day) ? .isSelected : [])
            }
        }
    }

    private func afterLastControls(minDays: Int, maxDays: Int) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            HStack {
                Text("Soonest").threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Text("\(minDays) days").threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("minDays")
                StepperPill(title: "soonest", canDecrement: minDays > 1, onDecrement: { form.stepMinDays(by: -1) }, onIncrement: { form.stepMinDays(by: 1) }).scaleEffect(0.85)
            }
            HStack {
                Text("Latest").threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Text("\(maxDays) days").threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("maxDays")
                StepperPill(title: "latest", canDecrement: maxDays > minDays, onDecrement: { form.stepMaxDays(by: -1) }, onIncrement: { form.stepMaxDays(by: 1) }).scaleEffect(0.85)
            }
            Text("When did you last do this?").threadsType(.label).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.tight)
            FlowChips {
                Chip(title: "Today", isSelected: form.draft.startDate == form.today) { form.markLastDoneToday() }
                Chip(title: "Due now", isSelected: form.draft.startDate == form.today.addingDays(-minDays)) { form.markDueNow() }
                    .accessibilityIdentifier("dueNow")
            }
        }
    }

    private var times: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Times").threadsType(.label).foregroundStyle(threads.ink2).padding(.bottom, ThreadsSpace.tight)
            Divider().overlay(threads.line)
            ForEach(Array(form.draft.slots.enumerated()), id: \.offset) { index, slot in
                Button { editingSlot = index } label: {
                    HStack {
                        Text(slot.label.isEmpty ? "Any time" : slot.label).threadsType(.lede).foregroundStyle(threads.ink)
                        Spacer(minLength: ThreadsSpace.tight)
                        Text(AnchorForm.summary(slot)).threadsType(.body).foregroundStyle(threads.ink2)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
                    }
                    .frame(minHeight: 56).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("slot-\(index)")
                Divider().overlay(threads.line)
            }
            if form.canAddSlot {
                Button { form.addSlot() } label: {
                    Label("Add a time", systemImage: "plus").threadsType(.lede).foregroundStyle(threads.ink)
                        .frame(minHeight: 52, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addSlot")
                Divider().overlay(threads.line)
            }
        }
    }

    private func stepperRow<Control: View>(_ title: String, _ value: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Text(value).threadsType(.lede).foregroundStyle(threads.ink)
                control()
            }
            .padding(.vertical, ThreadsSpace.tight)
            Divider().overlay(threads.line)
        }
    }

    private var placementRow: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Placement").threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Picker("Placement", selection: $form.draft.placement) {
                    Text("Fixed").tag(AnchorPlacement.fixed)
                    Text("Flexible").tag(AnchorPlacement.flexible)
                }
                .pickerStyle(.segmented).frame(width: 190)
            }
            .padding(.vertical, ThreadsSpace.tight)
            Divider().overlay(threads.line)
        }
    }

    private var endsRow: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ends").threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Toggle("Ends", isOn: Binding(
                    get: { hasEnd },
                    set: { on in hasEnd = on; form.draft.endDate = on ? form.today.addingDays(30) : nil })).labelsHidden()
                if hasEnd {
                    DatePicker("Ends", selection: Binding(
                        get: { (form.draft.endDate ?? form.today).pickerDate() },
                        set: { form.draft.endDate = CalendarDate(pickerDate: $0) }), displayedComponents: .date).labelsHidden()
                } else {
                    Text("Never").threadsType(.lede).foregroundStyle(threads.ink)
                }
            }
            .padding(.vertical, ThreadsSpace.tight)
            Divider().overlay(threads.line)
        }
    }

    private var reminderRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Remind me").threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer()
                Text(AnchorForm.reminderSummary(atStart: form.draft.remindAtStart, beforeEnd: form.draft.remindBeforeEndMinutes))
                    .threadsType(.lede).foregroundStyle(threads.ink)
            }
            .padding(.vertical, ThreadsSpace.row)
            Toggle("At the start", isOn: $form.draft.remindAtStart).threadsType(.lede).foregroundStyle(threads.ink)
            Toggle("Shortly before it closes", isOn: Binding(
                get: { form.draft.remindBeforeEndMinutes != nil },
                set: { form.draft.remindBeforeEndMinutes = $0 ? 10 : nil })).threadsType(.lede).foregroundStyle(threads.ink)
                .padding(.bottom, ThreadsSpace.tight)
            Divider().overlay(threads.line)
        }
    }

    // MARK: Save

    private func save() {
        do {
            if let rule { try AnchorEditing.update(rule, with: form.draft, now: .now) }
            else { try AnchorEditing.create(form.draft, in: context, now: .now) }
            AppEngine.syncAnchors(in: context)
            onFinished()
            dismiss()
        } catch let error as AnchorEditError {
            message = AnchorsCopy.message(for: error)
        } catch {
            message = "That couldn't be saved. Try again."
        }
    }
}

/// One time of a rule: its name, when it starts and how long the window stays open, or all day.
struct SlotEditorSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    @Binding var form: AnchorForm
    let index: Int

    private var slot: AnchorSlotDraft { form.draft.slots[index] }

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            Text("A time").threadsType(.display(.compact)).foregroundStyle(threads.ink)
            TextField("Name (Drop-off, Pick-up…)", text: Binding(get: { slot.label }, set: { form.draft.slots[index].label = $0 }))
                .threadsType(.lede).padding(.bottom, ThreadsSpace.tight)
                .overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                .accessibilityIdentifier("slotName")
            if form.draft.repeats.isCalendarBased {
                Toggle("All day", isOn: Binding(get: { slot.allDay }, set: { form.draft.slots[index].allDay = $0 }))
            }
            if !slot.allDay {
                DatePicker("Starts", selection: Binding(
                    get: { HabitForm.date(forMinute: slot.startMinute) },
                    set: { form.draft.slots[index].startMinute = HabitForm.minute(of: $0) }), displayedComponents: .hourAndMinute)
                HStack {
                    Text("Window").threadsType(.lede).foregroundStyle(threads.ink)
                    Spacer()
                    Text("\(slot.windowMinutes) min").threadsType(.lede).foregroundStyle(threads.ink)
                    StepperPill(title: "window", canDecrement: slot.windowMinutes > 5,
                                onDecrement: { var s = slot; AnchorForm.stepWindow(&s, by: -1); form.draft.slots[index] = s },
                                onIncrement: { var s = slot; AnchorForm.stepWindow(&s, by: 1); form.draft.slots[index] = s })
                        .scaleEffect(0.85)
                }
                Text("How long it stays open for you to do it.").threadsType(.meta).foregroundStyle(threads.ink2)
            }
            Spacer()
            if form.canRemoveSlot {
                Button(role: .destructive) { form.removeSlot(at: index); dismiss() } label: {
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
            .accessibilityIdentifier("slotDone")
        }
        .padding(ThreadsSpace.gutter)
        .background(threads.app)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
