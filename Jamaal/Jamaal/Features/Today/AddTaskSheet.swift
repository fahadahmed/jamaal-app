//
//  AddTaskSheet.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The add sheet (TK-01): a title, how long, how much it matters, when, a category and a repeat, and one
/// terracotta button that says what it will do. If the task would tip the day over, the panel offers the next
/// day with room, and *Add anyway* is always there: nothing here blocks.
struct AddTaskSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskCategory.sortOrder) private var allCategories: [TaskCategory]

    @State private var form: AddTaskForm
    @State private var dayFull: DayFullCheck?
    @State private var pickingDate = false
    @State private var showsEffortStepper = false
    @SwiftUI.FocusState private var titleFocused: Bool

    /// `dueDate` pre-fills the date: tomorrow, when adding from Night Planning's Build step.
    init(today: CalendarDate, dueDate: CalendarDate? = nil) {
        let calendarFirst = Calendar.current.firstWeekday                       // 1 = Sunday
        _form = State(initialValue: AddTaskForm(today: today, firstWeekdayISO: calendarFirst == 1 ? 7 : calendarFirst - 1, dueDate: dueDate))
    }

    private var categories: [TaskCategory] { allCategories.filter { !$0.isArchived } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                header
                TextField("What needs doing?", text: $form.draft.title)
                    .threadsType(.lede)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .padding(.bottom, ThreadsSpace.tight)
                    .overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                    .accessibilityLabel("Title")
                effortSection
                importanceSection
                dueSection
                optionRows
                if let dayFull { dayFullPanel(dayFull) }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.row)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(threads.app)
        .safeAreaInset(edge: .bottom) {
            Button(action: submit) {
                Text(form.buttonTitle).threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .disabled(!form.canSubmit)
            .opacity(form.canSubmit ? 1 : 0.45)
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.vertical, ThreadsSpace.tight)
            .background(threads.app)                                  // solid, so chips never show through it
            .accessibilityIdentifier("addTaskButton")
        }
        .onAppear { titleFocused = true }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").frame(width: ThreadsHit.minimum, height: ThreadsHit.minimum)
                    .foregroundStyle(threads.ink)
                    .background(Circle().fill(threads.card))
                    .overlay(Circle().strokeBorder(threads.line2, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            // The Anchor side of the switch arrives with the one-off Anchor form.
            Text("New task").threadsType(.label).foregroundStyle(threads.ink2)
            Spacer()
            Color.clear.frame(width: ThreadsHit.minimum, height: ThreadsHit.minimum)
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text("Effort").threadsType(.label).foregroundStyle(threads.ink2)
            FlowChips {
                ForEach(form.effortChips, id: \.self) { minutes in
                    Chip(title: AddTaskForm.effortTitle(minutes), isSelected: form.draft.effortMinutes == minutes) {
                        form.draft.effortMinutes = minutes
                    }
                }
                Chip(title: "Other…", isSelected: showsEffortStepper) { withAnimation(.snappy) { showsEffortStepper.toggle() } }
            }
            if showsEffortStepper {
                Stepper(value: Binding(get: { form.draft.effortMinutes ?? 30 }, set: { form.draft.effortMinutes = $0 }), in: 15...480, step: 15) {
                    Text(TodayCopy.duration(form.draft.effortMinutes ?? 30)).threadsType(.row).foregroundStyle(threads.ink)
                }
                .accessibilityLabel("Effort in minutes")
            }
        }
    }

    private var importanceSection: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text("How much does this matter?").threadsType(.label).foregroundStyle(threads.ink2)
            Picker("How much does this matter?", selection: Binding(get: { form.draft.importance }, set: { form.setImportance($0) })) {
                Text("Low").tag(Importance.low)
                Text("Medium").tag(Importance.medium)
                Text("High").tag(Importance.high)
            }
            .pickerStyle(.segmented)
        }
    }

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            HStack {
                Text("Due").threadsType(.label).foregroundStyle(threads.ink2)
                Spacer()
                if form.draft.importance != .low || form.draft.repeatKind != .off {
                    Text("Needed for medium, high and repeating").threadsType(.meta).foregroundStyle(threads.ink2)
                }
            }
            FlowChips {
                ForEach(form.dueOptions, id: \.kind) { option in
                    Chip(title: Self.title(option.kind), isSelected: form.draft.dueDate == option.date && !pickingDate) {
                        pickingDate = false
                        form.choose(option.date)
                    }
                }
                if let due = form.draft.dueDate, !form.dueOptions.contains(where: { $0.date == due }) {
                    Chip(title: AddTaskForm.dateTitle(due), isSelected: true) { pickingDate.toggle() }
                } else {
                    Chip(title: "Pick a date", isSelected: pickingDate) { pickingDate.toggle() }
                }
            }
            if pickingDate {
                DatePicker("Due date", selection: Binding(
                    get: { (form.draft.dueDate ?? form.today).pickerDate() },
                    set: { form.choose(CalendarDate(pickerDate: $0)) }
                ), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
        }
    }

    private var optionRows: some View {
        VStack(spacing: 0) {
            Divider().overlay(threads.line)
            Menu {
                Button("None") { form.draft.category = nil }
                ForEach(categories, id: \.id) { category in Button(category.name) { form.draft.category = category } }
            } label: {
                optionRow(title: "Category") {
                    if let category = form.draft.category {
                        Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 8, height: 8)
                        Text(category.name)
                    } else {
                        Text("None")
                    }
                }
            }
            .accessibilityIdentifier("categoryRow")
            Divider().overlay(threads.line)
            Menu {
                ForEach([RepeatKind.off, .daily, .weekly, .monthly], id: \.self) { kind in
                    Button(Self.title(kind)) { form.setRepeat(kind) }
                }
            } label: {
                optionRow(title: "Repeat") { Text(Self.title(form.draft.repeatKind)) }
            }
            .accessibilityIdentifier("repeatRow")
            Divider().overlay(threads.line)
        }
    }

    private func optionRow<Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 6) {
            Text(title).threadsType(.lede).foregroundStyle(threads.ink)
            Spacer()
            trailing().threadsType(.body).foregroundStyle(threads.ink2)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func dayFullPanel(_ check: DayFullCheck) -> some View {
        let copy = AddTaskForm.dayFullCopy(check, adding: form.draft.effortMinutes ?? 0, on: form.draft.dueDate ?? form.today, today: form.today)
        return VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text(copy.title).threadsType(.lede).foregroundStyle(threads.ink)
            Text(copy.detail).threadsType(.meta).foregroundStyle(threads.ink2)
            HStack(spacing: ThreadsSpace.tight) {
                if let suggestion = check.suggestion {
                    Button { form.choose(suggestion); save() } label: {
                        Text(AddTaskForm.relativeButton(suggestion, today: form.today)).threadsType(.row).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52).background(Capsule().fill(threads.terra))
                    }
                    .accessibilityIdentifier("dayFullOffer")
                }
                Button { save() } label: {
                    Text("Add anyway").threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 52).overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                }
                .accessibilityIdentifier("addAnyway")
            }
            .buttonStyle(.plain)
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(threads.line2, lineWidth: 1))
    }

    // MARK: Actions

    /// Add: checks the day first, and only creates the task when there is nothing to offer (or after the choice).
    private func submit() {
        guard form.canSubmit else { return }
        if dayFull == nil,
           let check = try? TaskCreation.dayFullCheck(adding: form.draft.effortMinutes, on: form.draft.dueDate, in: context, now: .now) {
            withAnimation(.snappy) { dayFull = check }
            return
        }
        save()
    }

    private func save() {
        do {
            try TaskCreation.create(form.draft, in: context, now: .now)
            dismiss()
        } catch {
            // The form already keeps a dated task dated, so this is only an empty title; the button was disabled.
        }
    }

    private static func title(_ kind: QuickDateKind) -> String {
        switch kind {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .laterThisWeek: "Later this week"
        case .nextWeek: "Next week"
        case .someday: "Someday"
        }
    }

    private static func title(_ kind: RepeatKind) -> String {
        switch kind {
        case .off, .unknown: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }
}
