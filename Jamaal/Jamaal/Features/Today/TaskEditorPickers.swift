//
//  TaskEditorPickers.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The fields the task editor can open (TK-02): each is a small picker that saves the moment something is chosen.
enum EditField: Hashable, Identifiable {
    case category, effort, matters, due, repeats
    var id: Self { self }

    var title: String {
        switch self {
        case .category: "Category"
        case .effort: "Effort"
        case .matters: "Matters"
        case .due: "Due"
        case .repeats: "Repeats"
        }
    }
}

/// A row in a picker: the chosen one is a white card with a 1.5 pt ink ring (never terracotta), as in the selected-row rule.
struct PickerRow: View {
    @Environment(\.threads) private var threads
    let title: String
    var detail: String?
    let isSelected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                    Text(title).threadsType(.row).foregroundStyle(threads.ink)
                    if let detail { Text(detail).threadsType(.meta).foregroundStyle(threads.ink2) }
                }
                Spacer()
            }
            .padding(.horizontal, ThreadsSpace.row)
            .frame(minHeight: ThreadsHit.minimum + 6)
            .background(
                RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(isSelected ? threads.card : .clear)
                    .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(isSelected ? threads.ink : .clear, lineWidth: 1.5)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

/// The frame every picker shares: a title and its content, with a back button when it is pushed inside the sheet.
struct PickerFrame<Content: View>: View {
    @Environment(\.threads) private var threads
    let title: String
    var showsBack = true
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.row) {
                if showsBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                            .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to task")
                    .accessibilityIdentifier("pickerBack")
                }
                Text(title).threadsType(.display(.compact)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                content()
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, showsBack ? ThreadsSpace.row : ThreadsSpace.section)
            .padding(.bottom, ThreadsSpace.section)
        }
        .scrollIndicators(.hidden)
        .background(threads.app)
        .hidesNavigationBar()
    }
}

struct EffortPicker: View {
    @Environment(\.threads) private var threads
    let task: TaskItem
    var showsBack = true
    let onChoose: (Int?) -> Void
    let onBack: () -> Void
    @State private var other = false

    var body: some View {
        PickerFrame(title: "Effort", showsBack: showsBack, onBack: onBack) {
            VStack(spacing: ThreadsSpace.hair) {
                ForEach(TaskEditCopy.effortOptions, id: \.self) { minutes in
                    PickerRow(title: TaskDetailCopy.effort(minutes), isSelected: task.effortMinutes == minutes, identifier: "effort-\(minutes)") {
                        onChoose(minutes)
                    }
                }
                PickerRow(title: "Other…", detail: customDetail, isSelected: other || isCustom, identifier: "effort-other") {
                    withAnimation(.snappy) { other.toggle() }
                }
                if other || isCustom {
                    Stepper(value: Binding(get: { task.effortMinutes ?? 30 }, set: { onChoose($0) }), in: 15...480, step: 15) {
                        Text(TodayCopy.duration(task.effortMinutes ?? 30)).threadsType(.row).foregroundStyle(threads.ink)
                    }
                    .padding(.horizontal, ThreadsSpace.row)
                    .accessibilityLabel("Effort in minutes")
                    .accessibilityIdentifier("effortStepper")
                }
                PickerRow(title: "No estimate", isSelected: task.effortMinutes == nil, identifier: "effort-none") { onChoose(nil) }
            }
            Text(TaskEditCopy.effortHelper).threadsType(.meta).foregroundStyle(threads.ink2)
        }
    }

    private var isCustom: Bool { task.effortMinutes.map { !TaskEditCopy.effortOptions.contains($0) } ?? false }
    private var customDetail: String? { isCustom ? task.effortMinutes.map(TaskDetailCopy.effort) : nil }
}

struct MattersPicker: View {
    let task: TaskItem
    var showsBack = true
    let onChoose: (Importance) -> Void
    let onBack: () -> Void

    var body: some View {
        PickerFrame(title: "Matters", showsBack: showsBack, onBack: onBack) {
            VStack(spacing: ThreadsSpace.hair) {
                ForEach([Importance.low, .medium, .high], id: \.self) { level in
                    PickerRow(title: TaskDetailCopy.matters(level), isSelected: task.importanceLevel == level, identifier: "matters-\(TaskDetailCopy.matters(level).lowercased())") {
                        onChoose(level)
                    }
                }
            }
        }
    }
}

struct CategoryPicker: View {
    let task: TaskItem
    var showsBack = true
    let categories: [TaskCategory]
    let onChoose: (TaskCategory?) -> Void
    let onBack: () -> Void

    var body: some View {
        PickerFrame(title: "Category", showsBack: showsBack, onBack: onBack) {
            VStack(spacing: ThreadsSpace.hair) {
                PickerRow(title: "None", isSelected: task.category == nil, identifier: "category-none") { onChoose(nil) }
                ForEach(categories, id: \.id) { category in
                    PickerRow(title: category.name, isSelected: task.category?.id == category.id, identifier: "category-\(category.name)") { onChoose(category) }
                }
            }
        }
    }
}

struct RepeatPicker: View {
    let task: TaskItem
    var showsBack = true
    let onChoose: (RepeatKind) -> Void
    let onBack: () -> Void

    var body: some View {
        PickerFrame(title: "Repeats", showsBack: showsBack, onBack: onBack) {
            VStack(spacing: ThreadsSpace.hair) {
                ForEach([RepeatKind.off, .daily, .weekly, .monthly], id: \.self) { kind in
                    PickerRow(title: TaskDetailCopy.repeatName(kind), isSelected: task.repeatMode == kind, identifier: "repeat-\(TaskDetailCopy.repeatName(kind).lowercased())") {
                        onChoose(kind)
                    }
                }
            }
        }
    }
}

struct DuePicker: View {
    @Environment(\.threads) private var threads
    let task: TaskItem
    let today: CalendarDate
    let firstWeekdayISO: Int
    var showsBack = true
    /// `nil` is Someday.
    let onChoose: (CalendarDate?) -> Void
    let onBack: () -> Void

    private var due: CalendarDate? { task.dueDate.map(CalendarDate.init(storedDate:)) }
    private var needsDate: Bool { TaskPriority.isImportant(task) || task.repeatMode != .off }

    var body: some View {
        let options = QuickDates.options(today: today, firstWeekday: firstWeekdayISO, importance: task.importanceLevel, repeating: task.repeatMode != .off)
        PickerFrame(title: "Due", showsBack: showsBack, onBack: onBack) {
            VStack(spacing: ThreadsSpace.hair) {
                ForEach(options, id: \.kind) { option in
                    PickerRow(title: Self.title(option.kind), detail: option.date.map(AddTaskForm.dateTitle), isSelected: due == option.date, identifier: "due-\(option.kind.rawValue)") {
                        onChoose(option.date)
                    }
                }
            }
            if needsDate { Text(TaskEditCopy.somedayNeedsADate).threadsType(.meta).foregroundStyle(threads.ink2) }
            DatePicker("Due date", selection: Binding(
                get: { (due ?? today).pickerDate() },
                set: { onChoose(CalendarDate(pickerDate: $0)) }
            ), in: today.pickerDate()..., displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(threads.terra)
            .accessibilityIdentifier("dueCalendar")
        }
    }

    private static func title(_ kind: QuickDateKind) -> String {
        switch kind {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .laterThisWeek: "Later this week"
        case .nextWeek: "Next week"
        case .someday: "No date"
        }
    }
}
