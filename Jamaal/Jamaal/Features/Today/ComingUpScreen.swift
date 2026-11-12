//
//  ComingUpScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Coming up (UP-01): the tasks dated after today and one-off Anchors, by day for the next 14 days, then a collapsed *Later*.
/// Nothing here counts toward a day's capacity until that day is planned, so the rows are quiet (the tick's ring is dimmed) but
/// they work: a future task can be marked done. Pushed from Today's Coming up row.
struct ComingUpScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Observing these re-reads the list whenever a task or an Anchor changes, here or on another device.
    @Query private var tasks: [TaskItem]
    @Query private var anchors: [AnchorInstance]
    @State private var now = Date.now
    @State private var laterOpen = false
    @Environment(\.openTaskInPanel) private var openInPanel
    @State private var openTask: TaskItem?
    /// Ticked while this screen is open: kept in the list, struck through, so the tick can be taken back.
    @State private var ticked: Set<UUID> = []

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }

    var body: some View {
        let _ = (tasks.map { [$0.isCompleted ? 1 : 0, $0.droppedAt == nil ? 0 : 1, Int($0.dueDate?.timeIntervalSince1970 ?? 0)] },
                 anchors.map { [$0.attendanceStatus, $0.windowStart] as [AnyHashable] })
        let today = boundary.logicalDate(at: now)
        let coming = (try? ComingUp.read(in: context, today: today, boundary: boundary, keeping: ticked)) ?? ComingUp()
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    DisplayHeadline(first: "Coming up,", second: "not yet planned.")
                    Text(ComingUpCopy.note).threadsType(.lede).foregroundStyle(threads.ink2)
                }
                if coming.days.isEmpty && coming.later.isEmpty {
                    Text(ComingUpCopy.empty).threadsType(.lede).foregroundStyle(threads.ink2).accessibilityIdentifier("comingUpEmpty")
                }
                ForEach(coming.days, id: \.date) { day in daySection(day) }
                if !coming.later.isEmpty { later(coming.later) }
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
        .sheet(item: $openTask) { TaskDetailSheet(task: $0) }
    }

    private var topBar: some View {
        HStack(spacing: ThreadsSpace.row) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                    .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Today")
            .accessibilityIdentifier("comingUpBack")
            Text("Coming up").threadsType(.label).foregroundStyle(threads.ink2).accessibilityHidden(true)
            Spacer()
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, 8)
    }

    private func daySection(_ day: ComingUpDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(ComingUpCopy.dayHeading(day.date)).threadsType(.row).foregroundStyle(threads.ink)
                Spacer()
                Text(ComingUpCopy.howFar(daysAhead: day.daysAhead)).threadsType(.label).foregroundStyle(threads.ink2)
            }
            .padding(.bottom, ThreadsSpace.tight)
            .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(Array(day.items.enumerated()), id: \.offset) { _, item in
                row(item)
                Divider().overlay(threads.line)
            }
        }
    }

    private func later(_ items: [ComingUpItem]) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Button { withAnimation { laterOpen.toggle() } } label: {
                HStack {
                    Text(ComingUpCopy.laterTitle(count: items.count)).threadsType(.lede).foregroundStyle(threads.ink2)
                    Spacer()
                    Image(systemName: laterOpen ? "chevron.up" : "chevron.down").foregroundStyle(threads.ink3)
                }
                .frame(minHeight: ThreadsHit.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(laterOpen ? "Hides them" : "Shows them")
            .accessibilityIdentifier("comingUpLater")
            if laterOpen {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    row(item)
                    Divider().overlay(threads.line)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: ComingUpItem) -> some View {
        switch item.kind {
        case .task(let task): taskRow(task)
        case .oneOffAnchor(let anchor): anchorRow(anchor)
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: ThreadsSpace.row) {
            Button { tick(task) } label: { CheckCircle(isDone: task.isCompleted, isMuted: true) }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark \(task.title) not done" : "Mark \(task.title) done")
            Button { if let openInPanel { openInPanel(task) } else { openTask = task } } label: {
                VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                    Text(task.title).threadsType(.row)
                        .strikethrough(task.isCompleted, color: threads.ink3).foregroundStyle(threads.ink)
                    meta(task)
                }
                .padding(.top, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows its details")
        }
        .padding(.vertical, ThreadsSpace.hair)
        .accessibilityIdentifier("comingUpTask-\(task.title)")
    }

    private func meta(_ task: TaskItem) -> some View {
        HStack(spacing: ThreadsSpace.tight) {
            if let effort = ComingUpCopy.effort(task.effortMinutes) { Text(effort) }
            if let category = task.category, !category.name.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 8, height: 8)
                    Text(category.name)
                }
            }
        }
        .threadsType(.meta).foregroundStyle(threads.ink2)
    }

    /// A one-off Anchor has no tick here: attendance is marked on Today while its window is open.
    private func anchorRow(_ anchor: AnchorInstance) -> some View {
        HStack(alignment: .top, spacing: ThreadsSpace.row) {
            Color.clear.frame(width: ThreadsHit.minimum, height: 1)
            VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                Text(anchor.title).threadsType(.row).foregroundStyle(threads.ink)
                Text(ComingUpCopy.anchorMeta(time: Self.time.string(from: anchor.windowStart))).threadsType(.meta).foregroundStyle(threads.ink2)
            }
            .padding(.top, 9)
            Spacer(minLength: 0)
        }
        .padding(.vertical, ThreadsSpace.hair)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("comingUpAnchor-\(anchor.title)")
    }

    private func tick(_ task: TaskItem) {
        if task.isCompleted {
            try? TaskActions.uncomplete(task, boundary: boundary, context: context)
        } else {
            ticked.insert(task.id)
            TaskActions.complete(task, now: .now, boundary: boundary, context: context)
        }
        now = .now
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
