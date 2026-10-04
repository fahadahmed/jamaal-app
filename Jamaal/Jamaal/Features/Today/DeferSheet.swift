//
//  DeferSheet.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The defer picker (TK-03), opened from the third deferral: the companion's line, the easing note when this
/// deferral eases importance, a later day or Someday, and an optional reason. Never blocks and never scolds.
struct DeferSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let task: TaskItem
    let onMoved: () -> Void
    @State private var form: DeferForm
    @State private var pickingDate = false
    private let preview: TaskDeferral.Preview

    init(task: TaskItem, today: CalendarDate, onMoved: @escaping () -> Void) {
        self.task = task
        self.onMoved = onMoved
        let calendarFirst = Calendar.current.firstWeekday
        let preview = TaskDeferral.preview(task, from: today)
        self.preview = preview
        _form = State(initialValue: DeferForm(preview: preview, today: today, firstWeekdayISO: calendarFirst == 1 ? 7 : calendarFirst - 1))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text(TaskDetailCopy.ordinal(preview.ordinal)).threadsType(.label).foregroundStyle(threads.ink2)
                    Text(task.title).threadsType(.display(.compact)).foregroundStyle(threads.ink)
                }
                HStack(alignment: .top, spacing: ThreadsSpace.row) {
                    CompanionMark()
                    VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                        Text(TaskDetailCopy.deferLine(preview)).threadsType(.lede).foregroundStyle(threads.ink)
                        if let ease = TaskDetailCopy.easeNote(preview) {
                            Text(ease).threadsType(.meta).foregroundStyle(threads.ink2)
                        }
                    }
                }
                VStack(spacing: 0) {
                    Divider().overlay(threads.line)
                    ForEach(form.options, id: \.kind) { option in
                        optionRow(title: Self.title(option.kind), detail: option.date.map(AddTaskForm.dateTitle) ?? "No date",
                                  isSelected: option.kind == .someday ? form.isSomeday : (form.target == option.date && !pickingDate)) {
                            pickingDate = false
                            if let date = option.date { form.choose(date) } else { form.chooseSomeday() }
                        }
                    }
                    Button { withAnimation(.snappy) { pickingDate.toggle() } } label: {
                        HStack {
                            Text("Pick a date").threadsType(.lede).foregroundStyle(threads.ink)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(threads.ink3).rotationEffect(.degrees(pickingDate ? 90 : 0))
                        }
                        .frame(minHeight: 52).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(threads.line)
                    if pickingDate {
                        DatePicker("Date", selection: Binding(
                            get: { (form.target ?? form.today.addingDays(1)).pickerDate() },
                            set: { form.choose(CalendarDate(pickerDate: $0)) }
                        ), in: form.today.addingDays(1).pickerDate()..., displayedComponents: .date)
                        .datePickerStyle(.graphical).labelsHidden()
                    }
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Why · optional").threadsType(.label).foregroundStyle(threads.ink2)
                    FlowChips {
                        ForEach(TaskDetailCopy.reasons, id: \.reason) { item in
                            Chip(title: item.title, isSelected: form.reason == item.reason) { form.toggleReason(item.reason) }
                        }
                    }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.section)
            .padding(.bottom, 100)
        }
        .background(threads.app)
        .safeAreaInset(edge: .bottom) {
            Button(action: move) {
                Text(form.moveTitle).threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, ThreadsSpace.gutter).padding(.vertical, ThreadsSpace.tight)
            .background(threads.app)
            .accessibilityIdentifier("moveButton")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func optionRow(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(title).threadsType(isSelected ? .row : .lede).foregroundStyle(threads.ink)
                    Spacer()
                    Text(detail).threadsType(.body).foregroundStyle(threads.ink2)
                    if isSelected { Image(systemName: "checkmark").foregroundStyle(threads.ink) }
                }
                .padding(.horizontal, isSelected ? ThreadsSpace.row : 0)
                .frame(minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 18).fill(isSelected ? threads.card : .clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            Divider().overlay(threads.line)
        }
    }

    private func move() {
        let boundary = TodayDay.boundary(in: context)
        _ = try? TaskDeferral.defer(task, from: form.today, to: form.target, reason: form.reason, now: .now, boundary: boundary, context: context)
        dismiss()
        onMoved()
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
}
