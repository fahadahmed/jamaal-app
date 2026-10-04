//
//  HabitsOverviewView.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The Habits segment (HB-01): groups as cards with a 14-day aggregate, ungrouped habits with a one-line status
/// (a paused one says why and when it resumes), and an Archived section with Restore.
struct HabitsOverviewView: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    // Observed so the overview re-reads when habits, entries or settings change, here or on another device.
    @Query private var habits: [Habit]
    @Query private var entries: [HabitEntry]
    @Query private var groups: [HabitGroup]
    @State private var now = Date.now
    @State private var openGroups: Set<UUID> = []
    @State private var archivedOpen = false

    var body: some View {
        let _ = (habits.map { [$0.isArchived ? 1 : 0, $0.pausesData.count, $0.title.count] as [AnyHashable] },
                 entries.map { [$0.amount, $0.completedAt == nil ? 0 : 1] }, groups.map { $0.title })
        let boundary = TodayDay.boundary(in: context)
        let overview = try? HabitsOverview.read(in: context, now: now, boundary: boundary, firstWeekday: Calendar.current.firstWeekday)
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                Text("Habits").threadsType(.display(.large)).foregroundStyle(threads.ink)
                    .accessibilityAddTraits(.isHeader)
                if let overview {
                    if overview.groups.isEmpty && overview.ungrouped.isEmpty && overview.archived.isEmpty {
                        Text("No habits yet — they'll appear as patterns do.").threadsType(.lede).foregroundStyle(threads.ink2)
                    }
                    ForEach(overview.groups, id: \.group.id) { group in groupCard(group) }
                    if !overview.groups.isEmpty && !overview.ungrouped.isEmpty { Divider().overlay(threads.line) }
                    VStack(spacing: 0) {
                        ForEach(overview.ungrouped, id: \.habit.id) { summary in
                            row(summary)
                            Divider().overlay(threads.line)
                        }
                    }
                    if !overview.archived.isEmpty { archivedSection(overview.archived) }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.row)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(threads.app)
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
    }

    // MARK: Pieces

    private func status(_ summary: HabitSummary) -> String {
        HabitsCopy.status(
            kind: summary.habit.habitKind,
            windows: summary.windows.map { HabitsCopy.WindowStatus(label: $0.window.label, startMinute: $0.window.startMinute, amount: $0.amount, target: $0.target, isDone: $0.isDone) },
            weekly: summary.weekly,
            pause: summary.pause.map { HabitsCopy.PauseStatus(reason: $0.reasonKind, endsOn: $0.to) })
    }

    private func row(_ summary: HabitSummary) -> some View {
        NavigationLink(value: summary.habit) {
            HStack {
                VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                    Text(summary.habit.title).threadsType(.row).foregroundStyle(summary.isPaused ? threads.ink2 : threads.ink)
                    Text(status(summary)).threadsType(.meta).foregroundStyle(threads.ink2)
                }
                Spacer(minLength: ThreadsSpace.tight)
                Image(systemName: "chevron.right").foregroundStyle(threads.ink3)
            }
            .padding(.vertical, ThreadsSpace.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func groupCard(_ group: HabitGroupSummary) -> some View {
        let isOpen = openGroups.contains(group.group.id)
        return VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            Button {
                withAnimation(.snappy) { if isOpen { openGroups.remove(group.group.id) } else { openGroups.insert(group.group.id) } }
            } label: {
                HStack {
                    Text(group.group.title).threadsType(.row).foregroundStyle(threads.ink)
                    Spacer()
                    Text(HabitsCopy.groupCount(done: group.doneToday, due: group.dueToday)).threadsType(.body).foregroundStyle(threads.ink2)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down").foregroundStyle(threads.ink3)
                }
                .frame(minHeight: ThreadsHit.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.group.title), \(HabitsCopy.groupCount(done: group.doneToday, due: group.dueToday))")
            .accessibilityHint(isOpen ? "Hides its habits" : "Shows its habits")
            .accessibilityIdentifier("group-\(group.group.title)")
            DensityGrid(cells: group.grid, columns: 14)
                .frame(maxWidth: .infinity)
            if isOpen {
                VStack(spacing: 0) {
                    ForEach(group.habits, id: \.habit.id) { summary in
                        NavigationLink(value: summary.habit) {
                            HStack(spacing: ThreadsSpace.row) {
                                CheckCircle(isDone: summary.windows.allSatisfy(\.isDone) && !summary.windows.isEmpty).scaleEffect(0.85)
                                Text(summary.habit.title).threadsType(.lede).foregroundStyle(summary.isPaused ? threads.ink2 : threads.ink)
                                Spacer()
                                Text(HabitsCopy.schedule(weekdays: summary.habit.scheduledWeekdays, perWeek: summary.habit.targetPerWeek))
                                    .threadsType(.body).foregroundStyle(threads.ink2)
                            }
                            .frame(minHeight: ThreadsHit.minimum)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, ThreadsSpace.tight)
                .overlay(alignment: .leading) { Rectangle().fill(threads.line).frame(width: 1) }
            }
        }
    }

    private func archivedSection(_ archived: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Divider().overlay(threads.line)
            Button { withAnimation(.snappy) { archivedOpen.toggle() } } label: {
                HStack {
                    Text(HabitsCopy.archived(count: archived.count)).threadsType(.label).foregroundStyle(threads.ink2)
                    Spacer()
                    Image(systemName: archivedOpen ? "chevron.up" : "chevron.down").foregroundStyle(threads.ink3)
                }
                .frame(minHeight: ThreadsHit.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("archivedToggle")
            if archivedOpen {
                ForEach(archived, id: \.id) { habit in
                    HStack {
                        Text(habit.title).threadsType(.lede).foregroundStyle(threads.ink2)
                        Spacer()
                        Button("Restore") { habit.isArchived = false }
                            .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                            .frame(minHeight: ThreadsHit.minimum)
                            .accessibilityLabel("Restore \(habit.title)")
                    }
                }
            }
        }
    }
}
