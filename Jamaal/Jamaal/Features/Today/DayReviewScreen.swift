//
//  DayReviewScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Day review (DY-01): one closed day, read-only. The hero, the capacity used, Anchors, Habits and Tasks, with arrows to the days
/// either side (back to the first day with data; forward to yesterday, as today has its own screen). A missed task can be ticked for
/// two days. Everything is read from what is already stored, so nothing here adds data.
struct DayReviewScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Observing these re-reads the day when anything it shows changes.
    @Query private var tasks: [TaskItem]
    @Query private var anchors: [AnchorInstance]
    @Query private var entries: [HabitEntry]
    @State private var day: CalendarDate
    @State private var now = Date.now
    /// In the detail column beside the list (a wide layout) there is no back button: the list stays where it is.
    var embedded = false

    init(day: CalendarDate, embedded: Bool = false) {
        _day = State(initialValue: day)
        self.embedded = embedded
    }

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }

    var body: some View {
        let _ = (tasks.map { [$0.isCompleted ? 1 : 0, Int($0.completedAt?.timeIntervalSince1970 ?? 0), $0.deferrals?.count ?? 0] },
                 anchors.map { [$0.attendanceStatus] as [AnyHashable] }, entries.map { [$0.amount] })
        let today = boundary.logicalDate(at: now)
        let past = try? PastDay.read(on: day, today: today, boundary: boundary, now: now, context: context)
        let near = (try? PastDay.neighbours(of: day, today: today, boundary: boundary, context: context)) ?? PastDayNeighbours()
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                if let past {
                    let hero = DayReviewCopy.hero(done: past.doneCount, planned: past.plannedCount)
                    DisplayHeadline(first: hero.0, second: hero.1)
                    capacity(past)
                    if !past.anchors.isEmpty { anchorsSection(past) }
                    if !past.habits.isEmpty { habitsSection(past) }
                    if !past.tasks.isEmpty { tasksSection(past, today: today) }
                    if past.anchors.isEmpty && past.habits.isEmpty && past.tasks.isEmpty {
                        Text(DayReviewCopy.empty).threadsType(.lede).foregroundStyle(threads.ink2).accessibilityIdentifier("dayReviewEmpty")
                    }
                    Text(DayReviewCopy.footer).threadsType(.meta).foregroundStyle(threads.ink2)
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, 76)
            .padding(.bottom, 80)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) { topBar(near).readableColumn() }
        .background(threads.app.ignoresSafeArea())
        .hidesNavigationBar()
    }

    // MARK: Chrome

    private func topBar(_ near: PastDayNeighbours) -> some View {
        HStack(spacing: ThreadsSpace.row) {
            if !embedded {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                        .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Today")
                .accessibilityIdentifier("dayReviewBack")
            }
            Text(DayReviewCopy.eyebrow(day)).threadsType(.label).foregroundStyle(threads.ink2)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("dayReviewDate")
            Spacer()
            HStack(spacing: 0) {
                arrow("chevron.left", "Previous day", id: "dayReviewPrevious", target: near.previous, key: "[")
                arrow("chevron.right", "Next day", id: "dayReviewNext", target: near.next, key: "]")
            }
            .padding(.horizontal, 4).frame(height: 48)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, 8)
    }

    /// ⌘[ and ⌘] step between days (a Mac, or an iPad with a keyboard).
    private func arrow(_ symbol: String, _ label: String, id: String, target: CalendarDate?, key: KeyEquivalent) -> some View {
        Button { if let target { day = target } } label: {
            Image(systemName: symbol).font(.body.weight(.semibold))
                .foregroundStyle(target == nil ? threads.ink3.opacity(0.4) : threads.ink)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: .command)
        .disabled(target == nil)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    // MARK: Sections

    private func capacity(_ past: PastDay) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            // One line at normal sizes; at accessibility sizes the capacity and the close time each get a line instead of tearing apart.
            AdaptiveRow {
                Text(DayReviewCopy.used(usedMinutes: past.usedMinutes, budgetMinutes: past.budgetMinutes)).threadsType(.lede).foregroundStyle(threads.ink)
            } trailing: {
                if let closed = past.closedAt {
                    Text(DayReviewCopy.closed(time: Self.time.string(from: closed))).threadsType(.label).foregroundStyle(threads.ink2)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(threads.line)
                    Capsule().fill(threads.deep)
                        .frame(width: geo.size.width * min(1, Double(past.usedMinutes) / Double(max(1, past.budgetMinutes))))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
    }

    private func anchorsSection(_ past: PastDay) -> some View {
        // One row per rule: "Salah, 4 of 5 attended" with a square for each; a one-off or a rule's single Anchor reads by its outcome.
        let groups = Dictionary(grouping: past.anchors) { $0.anchor.rule?.id ?? $0.anchor.id }
            .values.sorted { ($0.first?.anchor.windowStart ?? .distantPast) < ($1.first?.anchor.windowStart ?? .distantPast) }
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "ANCHORS").padding(.bottom, ThreadsSpace.tight)
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                let first = group[0]
                let counted = group.filter { $0.status != .skipped && $0.status != .delegated }
                let line = group.count > 1
                    ? DayReviewCopy.anchorGroup(attended: group.filter { $0.status == .attended }.count, counted: counted.count)
                    : DayReviewCopy.anchorOutcome(first.status, time: first.anchor.resolvedAt.map(Self.time.string(from:)))
                reviewRow(title: first.anchor.rule?.title ?? first.anchor.title, line: line) {
                    HStack(spacing: 4) { ForEach(Array(group.enumerated()), id: \.offset) { _, a in square(anchorColor(a.status)) } }
                }
            }
        }
    }

    private func habitsSection(_ past: PastDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "HABITS").padding(.bottom, ThreadsSpace.tight)
            ForEach(Array(past.habits.enumerated()), id: \.offset) { _, h in
                reviewRow(
                    title: h.habit.title,
                    line: DayReviewCopy.habit(kind: h.habit.habitKind, state: h.state, amount: h.amount, target: h.target)
                ) { square(habitColor(h.state)) }
            }
        }
    }

    private func tasksSection(_ past: PastDay, today: CalendarDate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "TASKS").padding(.bottom, ThreadsSpace.tight)
            ForEach(Array(past.tasks.enumerated()), id: \.offset) { _, item in
                taskRow(item, today: today)
                Divider().overlay(threads.line)
            }
        }
    }

    private func taskRow(_ item: PastTask, today: CalendarDate) -> some View {
        let task = item.task
        var isDone = false
        var doneTime: String?
        if case .done(let at) = item.outcome { isDone = true; doneTime = Self.time.string(from: at) }
        let dimmed = { () -> Bool in if case .deferred = item.outcome { true } else { false } }()
        return HStack(alignment: .top, spacing: ThreadsSpace.row) {
            CheckCircle(isDone: isDone, isMuted: true)
            VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                Text(task.title).threadsType(.row).strikethrough(isDone, color: threads.ink3)
                    .foregroundStyle(dimmed ? threads.ink2 : threads.ink)
                HStack(spacing: ThreadsSpace.tight) {
                    Text(DayReviewCopy.task(item.outcome, doneTime: doneTime))
                    if let category = task.category, !category.name.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 8, height: 8)
                            Text(category.name)
                        }
                    }
                }
                .threadsType(.meta).foregroundStyle(threads.ink2)
            }
            .padding(.top, 9)
            Spacer(minLength: 0)
            if item.canMarkDone {
                PillButton(title: "Mark done") { markDone(task, today: today) }
                    .accessibilityIdentifier("dayReviewMarkDone-\(task.title)")
            }
        }
        .padding(.vertical, ThreadsSpace.hair)
        .accessibilityElement(children: .contain)
    }

    private func reviewRow<Trailing: View>(title: String, line: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                Text(title).threadsType(.row).foregroundStyle(threads.ink)
                Text(line).threadsType(.meta).foregroundStyle(threads.ink2)
            }
            Spacer(minLength: ThreadsSpace.row)
            trailing().accessibilityHidden(true)
        }
        .padding(.vertical, ThreadsSpace.tight)
        .accessibilityElement(children: .combine)
    }

    private func square(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color).frame(width: 16, height: 16)
    }

    private func anchorColor(_ status: AttendanceStatus) -> Color {
        switch status {
        case .attended: threads.deep
        case .missed: threads.missed
        default: threads.line
        }
    }

    private func habitColor(_ state: DensityState) -> Color {
        switch state {
        case .complete: threads.d1
        case .partialHigh: threads.d2
        case .partialLow: threads.d3
        case .missed: threads.missed
        case .empty: threads.line
        }
    }

    // MARK: Fixing a missed task

    private func markDone(_ task: TaskItem, today: CalendarDate) {
        try? TaskActions.completeOnPastDay(task, day: day, today: today, now: .now, boundary: boundary, context: context)
        now = .now
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
