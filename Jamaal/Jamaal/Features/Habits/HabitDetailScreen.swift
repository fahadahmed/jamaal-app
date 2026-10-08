//
//  HabitDetailScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// A habit's detail (HB-02): today's control, the six-week density grid (the last 14 days can be corrected), a plain
/// read, and Pause / Resume / Archive. A grid per time of day when a habit has several.
struct HabitDetailScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.requireAccess) private var requireAccess
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(FocusCoordinator.self) private var focus

    let habit: Habit
    /// In the pane beside the list (regular width): no back button, and archiving clears the selection.
    var embedded = false
    var onClose: () -> Void = {}
    private func closeOrPop() { embedded ? onClose() : dismiss() }
    @Query private var entries: [HabitEntry]
    @State private var now = Date.now
    @State private var pausing = false
    @State private var editing = false
    @State private var correcting: Correction?

    private struct Correction: Identifiable {
        var window: HabitTimeWindow
        var day: CalendarDate
        var id: String { "\(window.id)-\(day.isoString)" }
    }

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }
    private var today: CalendarDate { boundary.logicalDate(at: now) }
    private var windows: [HabitTimeWindow] {
        (habit.windows ?? []).sorted { ($0.startMinute, $0.label, $0.id.uuidString) < ($1.startMinute, $1.label, $1.id.uuidString) }
    }

    private func habitContext() -> HabitContext {
        HabitContext(
            boundary: boundary, today: today, firstWeekday: Calendar.current.firstWeekday,
            engagedDays: (try? Engagement.engagedDays(in: context, boundary: boundary)) ?? [])
    }

    var body: some View {
        let _ = entries.map { [$0.amount, $0.completedAt == nil ? 0 : 1] }
        let hc = habitContext()
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text(HabitsCopy.eyebrow(
                        kind: habit.habitKind, target: windows.first?.target ?? 1,
                        weekly: habit.targetPerWeek)).threadsType(.label).foregroundStyle(threads.ink2)
                    Text(habit.title).threadsType(.display(.large)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                }
                if let pause = HabitPauses.active(habit, on: today) { pausedNote(pause) }
                ForEach(windows, id: \.id) { window in windowSection(window, context: hc) }
                readSection(hc)
                VStack(spacing: 0) {
                    Divider().overlay(threads.line)
                    row("Schedule", HabitsCopy.schedule(weekdays: habit.scheduledWeekdays, perWeek: habit.targetPerWeek))
                    if let reminder = windows.compactMap(\.reminderMinute).first { row("Reminder", PlanningCopy.clock(reminder)) }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, 76)
            .padding(.bottom, 80)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) { topBar.readableColumn() }
        .background(threads.app.ignoresSafeArea())
        .hidesNavigationBar()
        .sheet(isPresented: $pausing) { PauseSheet(habit: habit, today: today) }
        .sheet(isPresented: $editing) { NavigationStack { HabitFormScreen(editing: habit) } }
        .sheet(item: $correcting) { item in
            if habit.habitKind == .timed { AddMinutesSheet(habit: habit, window: item.window, day: item.day) }
            else { DayCorrectionSheet(habit: habit, window: item.window, day: item.day) }
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            if !embedded {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                        .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle())
                        .contentShape(Circle())                  // the whole circle is the button, not just the glyph
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            Spacer()
            Menu {
                Button("Edit habit…") { if requireAccess(.editHabit) { editing = true } }
                if HabitPauses.active(habit, on: today) != nil {
                    Button("Resume") { if requireAccess(.pauseHabit) { HabitPauses.resume(habit, on: today) } }
                } else {
                    Button("Pause…") { if requireAccess(.pauseHabit) { pausing = true } }
                }
                Button("Archive", role: .destructive) { if requireAccess(.archiveOrRestore) { habit.isArchived = true; closeOrPop() } }
            } label: {
                HStack(spacing: 6) { Text("Edit").threadsType(.row); Image(systemName: "chevron.down").font(.footnote) }
                    .foregroundStyle(threads.ink).padding(.horizontal, 20).frame(height: 48)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .contentShape(Capsule())
            }
            .accessibilityIdentifier("habitMenu")
        }
        .padding(.horizontal, ThreadsSpace.row)
        .padding(.top, ThreadsSpace.hair)
    }

    private func pausedNote(_ pause: HabitPause) -> some View {
        HStack(alignment: .top, spacing: ThreadsSpace.row) {
            Image(systemName: "pause.circle").font(.title3).foregroundStyle(threads.ink2)
            Text(HabitsCopy.status(
                kind: habit.habitKind, windows: [], weekly: nil,
                pause: HabitsCopy.PauseStatus(reason: pause.reasonKind, endsOn: pause.to)))
                .threadsType(.lede).foregroundStyle(threads.ink)
        }
        .accessibilityIdentifier("pausedNote")
    }

    private func windowSection(_ window: HabitTimeWindow, context hc: HabitContext) -> some View {
        let entry = (window.entries ?? []).filter { CalendarDate(storedDate: $0.date) == today }.max { $0.amount < $1.amount }
        let amount = entry?.amount ?? 0
        let target = max(habit.habitKind == .avoid ? 0 : 1, entry?.target ?? window.target)
        let cells = HabitDensity.grid(of: window, days: 42, context: hc)
        return VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            if !habit.isPaused(on: today) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(todayLine(kind: habit.habitKind, amount: amount, target: target, done: entry?.completedAt != nil || amount >= max(1, target)))
                            .threadsType(.row).foregroundStyle(threads.ink)
                        Text(window.label.isEmpty ? "All day" : window.label).threadsType(.meta).foregroundStyle(threads.ink2)
                    }
                    Spacer()
                    todayControl(window, amount: amount, target: target, isHeld: entry?.completedAt != nil)
                }
            }
            HStack {
                Text("Last 6 weeks").threadsType(.label).foregroundStyle(threads.ink2)
                Spacer()
                Text("Today").threadsType(.label).foregroundStyle(threads.ink2)
            }
            DensityGrid(
                cells: cells, columns: 14,
                onTap: { cell in correcting = Correction(window: window, day: cell.day) },
                isTappable: { cell in HabitLogging.canCorrect(habit, day: cell.day, today: today, boundary: boundary) })
        }
    }

    private func todayLine(kind: HabitKind, amount: Int, target: Int, done: Bool) -> String {
        switch kind {
        case .counted: "\(amount) of \(target) today"
        case .timed: "\(amount) of \(target) min today"
        case .avoid: done ? "Held today" : (amount == 0 ? "None yet today" : "\(amount) \(amount == 1 ? "slip" : "slips") today")
        case .binary, .unknown: done ? "Done today" : "Not yet today"
        }
    }

    @ViewBuilder private func todayControl(_ window: HabitTimeWindow, amount: Int, target: Int, isHeld: Bool) -> some View {
        switch habit.habitKind {
        case .counted:
            StepperPill(title: habit.title, canDecrement: amount > 0,
                        onDecrement: { log(.decrement, window) }, onIncrement: { log(.increment, window) })
        case .binary, .unknown:
            Button { log(.toggle, window) } label: { CheckCircle(isDone: amount >= max(1, target)) }
                .buttonStyle(.plain)
                .accessibilityLabel(amount >= max(1, target) ? "Mark \(habit.title) not done" : "Mark \(habit.title) done")
        case .timed:
            HStack(spacing: ThreadsSpace.tight) {
                PillButton(title: "Add minutes") { correcting = Correction(window: window, day: today) }
                    .accessibilityLabel("Add minutes to \(habit.title)")
                PillButton(title: "Begin") { focus.begin(.habit(window)) }.accessibilityLabel("Begin \(habit.title)")
            }
        case .avoid:
            HStack(spacing: ThreadsSpace.tight) {
                PillButton(title: "Slip") { log(.logSlip, window) }.accessibilityLabel("Log a slip for \(habit.title)")
                PillButton(title: isHeld ? "Undo" : "Held today") { log(isHeld ? .undoHeld : .heldToday, window) }
                    .accessibilityLabel(isHeld ? "Undo held today for \(habit.title)" : "Held today: \(habit.title)")
            }
        }
    }

    private func readSection(_ hc: HabitContext) -> some View {
        let read = HabitDensity.read(of: habit, windowDays: 42, context: hc)
        return Text(HabitsCopy.read(read, kind: habit.habitKind)).threadsType(.lede).foregroundStyle(threads.ink)
            .accessibilityIdentifier("habitRead")
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

    private func log(_ action: HabitLogAction, _ window: HabitTimeWindow) {
        now = .now
        try? HabitLogging.apply(action, to: window, on: boundary.logicalDate(at: now), now: now, context: context)
    }
}

// MARK: - Pause

/// Pause with a reason (HB-06): from today, until a date or until it is resumed. Paused days are empty cells, not misses.
struct PauseSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let today: CalendarDate
    @State private var reason: PauseReason = .travel
    @State private var untilResumed = true
    @State private var until: Date

    init(habit: Habit, today: CalendarDate) {
        self.habit = habit
        self.today = today
        _until = State(initialValue: today.addingDays(7).pickerDate())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("PAUSE").threadsType(.label).foregroundStyle(threads.ink2)
                    Text(habit.title).threadsType(.display(.compact)).foregroundStyle(threads.ink)
                    Text("Paused days stay empty. Nothing counts against it.").threadsType(.lede).foregroundStyle(threads.ink2)
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Until").threadsType(.label).foregroundStyle(threads.ink2)
                    FlowChips {
                        Chip(title: "I resume it", isSelected: untilResumed) { untilResumed = true }
                            .accessibilityIdentifier("untilResumed")
                        Chip(title: "A date", isSelected: !untilResumed) { untilResumed = false }
                    }
                    if !untilResumed {
                        DatePicker("Until", selection: $until, in: today.pickerDate()..., displayedComponents: .date)
                            .datePickerStyle(.graphical).labelsHidden()
                    }
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Why · optional").threadsType(.label).foregroundStyle(threads.ink2)
                    FlowChips {
                        ForEach([PauseReason.travel, .illness, .cycle, .other], id: \.self) { item in
                            Chip(title: HabitsCopy.reasonTitle(item), isSelected: reason == item) { reason = item }
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
            Button(action: pause) {
                Text("Pause").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, ThreadsSpace.gutter).padding(.vertical, ThreadsSpace.tight)
            .background(threads.app)
            .accessibilityIdentifier("pauseConfirm")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func pause() {
        let end = untilResumed ? nil : CalendarDate(pickerDate: until)
        try? HabitPauses.pause(habit, from: today, until: end, reason: reason)
        dismiss()
    }
}

// MARK: - Correct a day

/// Put right a day in the last 14: a tick, a count, or slips and Held. The numbers it writes are the ordinary entry's.
struct DayCorrectionSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let window: HabitTimeWindow
    let day: CalendarDate

    private var entry: HabitEntry? {
        (window.entries ?? []).filter { CalendarDate(storedDate: $0.date) == day }.max { $0.amount < $1.amount }
    }

    var body: some View {
        let amount = entry?.amount ?? 0
        let target = max(habit.habitKind == .avoid ? 0 : 1, entry?.target ?? window.target)
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                Text("CORRECT A DAY").threadsType(.label).foregroundStyle(threads.ink2)
                Text(AddTaskForm.dateTitle(day)).threadsType(.display(.compact)).foregroundStyle(threads.ink)
                Text(habit.title).threadsType(.lede).foregroundStyle(threads.ink2)
            }
            control(amount: amount, target: target)
            Button { dismiss() } label: {
                Text("Done").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("correctionDone")
        }
        .padding(ThreadsSpace.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(threads.app)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private func control(amount: Int, target: Int) -> some View {
        switch habit.habitKind {
        case .counted:
            HStack {
                Text("\(amount) of \(target)").threadsType(.row).foregroundStyle(threads.ink)
                Spacer()
                StepperPill(title: "\(habit.title) on that day", canDecrement: amount > 0, onDecrement: { apply(.decrement) }, onIncrement: { apply(.increment) })
            }
        case .avoid:
            let held = entry?.completedAt != nil
            HStack {
                Text(held ? "Held" : (amount == 0 ? "Nothing logged" : "\(amount) \(amount == 1 ? "slip" : "slips")")).threadsType(.row).foregroundStyle(threads.ink)
                Spacer()
                HStack(spacing: ThreadsSpace.tight) {
                    PillButton(title: "Slip", dashed: true) { apply(.logSlip) }
                    PillButton(title: held ? "Undo" : "Held") { apply(held ? .undoHeld : .heldToday) }
                }
            }
        case .binary, .unknown, .timed:
            HStack {
                Text(amount >= max(1, target) ? "Done" : "Not done").threadsType(.row).foregroundStyle(threads.ink)
                Spacer()
                Button { apply(.toggle) } label: { CheckCircle(isDone: amount >= max(1, target)) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(amount >= max(1, target) ? "Mark not done" : "Mark done")
                    .accessibilityIdentifier("correctionToggle")
            }
        }
    }

    private func apply(_ action: HabitLogAction) {
        try? HabitLogging.apply(action, to: window, on: day, now: .now, context: context)
    }
}
