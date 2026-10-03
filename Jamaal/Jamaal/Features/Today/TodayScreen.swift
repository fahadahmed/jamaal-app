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
    @State private var now: Date = .now
    @State private var alsoTodayOpen = false

    var body: some View {
        // Reading the attributes Today depends on makes SwiftUI re-run this body when any of them changes,
        // including from another device's sync; the overview itself is then re-read from the store.
        let _ = (tasks.map { [$0.isCompleted ? 1 : 0, $0.droppedAt == nil ? 0 : 1, $0.effortMinutes ?? -1, Int($0.dueDate?.timeIntervalSince1970 ?? 0)] },
                 plans.map { $0.capacity }, settings.map { [$0.mediumDayMinutes, $0.rolloverMinute] })
        let overview = try? TodayDay.overview(in: context, now: now)
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
