//
//  TodayScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Today (TD-01), first slice: the date, the headline, the capacity meter and slider, and the **Tasks**
/// section with *Also today*. Anchors, Habits, banners, the toolbar and the wellbeing strip follow.
struct TodayScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    // Observing these re-reads Today whenever a task or a day's plan changes, here or on another device.
    @Query private var tasks: [TaskItem]
    @Query private var plans: [DayPlan]
    @Query private var settings: [UserSettings]
    @Query private var anchors: [AnchorInstance]
    @Query private var habitEntries: [HabitEntry]
    @Query private var habits: [Habit]
    @State private var now: Date = .now
    @State private var alsoTodayOpen = false
    @State private var choosing: AnchorInstance?

    var body: some View {
        // Reading the attributes Today depends on makes SwiftUI re-run this body when any of them changes,
        // including from another device's sync; the overview itself is then re-read from the store.
        let _ = (tasks.map { [$0.isCompleted ? 1 : 0, $0.droppedAt == nil ? 0 : 1, $0.effortMinutes ?? -1, Int($0.dueDate?.timeIntervalSince1970 ?? 0)] },
                 plans.map { $0.capacity },
                 anchors.map { [$0.attendanceStatus, $0.windowStart, $0.windowEnd] as [AnyHashable] },
                 habitEntries.map { [$0.amount, $0.completedAt == nil ? 0 : 1] }, habits.map { [$0.isArchived ? 1 : 0, $0.pausesData.count] as [AnyHashable] }, settings.map { [$0.mediumDayMinutes, $0.rolloverMinute] })
        let overview = try? TodayDay.overview(in: context, now: now)
        let todayHabits = try? TodayHabits.read(
            in: context, now: now, boundary: TodayDay.boundary(in: context), firstWeekday: Calendar.current.firstWeekday)
        let anchorItems = (try? TodayAnchors.items(in: context, now: now, boundary: TodayDay.boundary(in: context))) ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                if let overview {
                    header(overview)
                    CapacityMeter(
                        plannedMinutes: overview.plannedMinutes, budgetMinutes: overview.budgetMinutes,
                        state: overview.state, loadScore: overview.loadScore
                    )
                    CapacitySlider(level: overview.level) { level in
                        try? TodayDay.setLevel(level, in: context, now: now)
                    }
                    anchorsSection(anchorItems)
                    habitsSection(todayHabits)
                    tasksSection(overview)
                    alsoToday(overview)
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.row)
            .padding(.bottom, 120)                                          // clear of the floating tab bar
        }
        .scrollIndicators(.hidden)
        .background(threads.app)
        .confirmationDialog(
            choosing?.title ?? "", isPresented: Binding(get: { choosing != nil }, set: { if !$0 { choosing = nil } }), titleVisibility: .visible
        ) {
            if let anchor = choosing {
                ForEach(TodayAnchors.actions(for: anchor, now: now, boundary: TodayDay.boundary(in: context)), id: \.self) { action in
                    Button(TodayCopy.title(for: action)) { perform(action, on: anchor) }
                }
            }
        }
        // The window bars and states move with the clock, so look again each minute.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = .now
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
    }

    private func header(_ overview: TodayOverview) -> some View {
        let remaining = overview.shown.count
        let headline = TodayCopy.headline(remaining: remaining)
        return VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            Text(TodayCopy.headerLabel(overview.today)).threadsType(.label).foregroundStyle(threads.ink2)
            DisplayHeadline(first: headline.first, second: headline.second)
        }
    }

    @ViewBuilder
    private func anchorsSection(_ items: [TodayAnchorItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                SectionLabel(title: "Anchors")
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .plain(let row):
                        AnchorRowView(row: row, onTick: { tick(row) }, onOpen: { choosing = row.anchor })
                    case .group(let group):
                        AnchorGroupRowView(group: group, onTick: tick, onOpen: { choosing = $0.anchor })
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func habitsSection(_ habits: TodayHabits?) -> some View {
        if let habits, habits.total > 0 {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                SectionLabel(title: "Habits")
                    .accessibilityValue(TodayCopy.habitsSummary(done: habits.done, total: habits.total))
                ForEach(habits.groups, id: \.group.id) { group in
                    HabitGroupView(group: group) { row, action in log(action, on: row) }
                }
                ForEach(Array(habits.rows.enumerated()), id: \.element.window.id) { index, row in
                    HabitRowView(row: row) { log($0, on: row) }
                    if index < habits.rows.count - 1 { Divider().overlay(threads.line) }
                }
            }
        }
    }

    private func log(_ action: HabitLogAction, on row: TodayHabitRow) {
        now = .now
        let today = TodayDay.boundary(in: context).logicalDate(at: now)
        try? HabitLogging.apply(action, to: row.window, on: today, now: now, context: context)
    }

    @ViewBuilder
    private func tasksSection(_ overview: TodayOverview) -> some View {
        let rows = overview.shown + overview.completedToday
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                SectionLabel(title: "Tasks")
                ForEach(rows, id: \.id) { task in
                    TaskRow(task: task, doneTime: task.completedAt.map(Self.timeFormat.string(from:))) { toggle(task) }
                }
            }
        }
    }

    @ViewBuilder
    private func alsoToday(_ overview: TodayOverview) -> some View {
        if !overview.alsoToday.isEmpty {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                Divider().overlay(threads.line)
                Button { withAnimation { alsoTodayOpen.toggle() } } label: {
                    HStack {
                        Text("Also today · \(overview.alsoToday.count)").threadsType(.lede).foregroundStyle(threads.ink2)
                        Spacer()
                        Image(systemName: alsoTodayOpen ? "chevron.up" : "chevron.down").foregroundStyle(threads.ink3)
                    }
                    .frame(minHeight: ThreadsHit.minimum)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(alsoTodayOpen ? "Hides them" : "Shows them")
                if alsoTodayOpen {
                    ForEach(overview.alsoToday, id: \.id) { task in
                        TaskRow(task: task, doneTime: nil) { toggle(task) }
                    }
                }
            }
        }
    }

    /// The tick on an Anchor: Attended while the window is open, or undo once attended.
    private func tick(_ row: TodayAnchorRow) {
        perform(row.status == .attended ? .undo : .attended, on: row.anchor)
    }

    private func perform(_ action: AnchorAction, on anchor: AnchorInstance) {
        now = .now
        try? TodayAnchors.perform(action, on: anchor, now: now, boundary: TodayDay.boundary(in: context))
    }

    private func toggle(_ task: TaskItem) {
        let boundary = TodayDay.boundary(in: context)
        if task.isCompleted {
            try? TaskActions.uncomplete(task, boundary: boundary, context: context)
        } else {
            TaskActions.complete(task, now: .now, boundary: boundary, context: context)
        }
        now = .now
    }

    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
