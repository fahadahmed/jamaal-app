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
    @Environment(FocusCoordinator.self) private var focus

    // Observing these re-reads Today whenever a task or a day's plan changes, here or on another device.
    @Query private var tasks: [TaskItem]
    @Query private var plans: [DayPlan]
    @Query private var settings: [UserSettings]
    @Query private var anchors: [AnchorInstance]
    @Query private var habitEntries: [HabitEntry]
    @Query private var habits: [Habit]
    @Query private var sessions: [WorkSession]
    @State private var now: Date = .now
    @State private var alsoTodayOpen = false
    @State private var choosing: AnchorInstance?
    @State private var isAdding = false
    @State private var openTask: TaskItem?
    @State private var planning: PlanningFlow?
    // The category filter is local to this device and this day: it clears at the rollover and on relaunch.
    @State private var filterID: UUID?
    @State private var dismissedPickUps: Set<UUID> = []
    @Query(sort: \TaskCategory.sortOrder) private var allCategories: [TaskCategory]

    var body: some View {
        // Reading the attributes Today depends on makes SwiftUI re-run this body when any of them changes,
        // including from another device's sync; the overview itself is then re-read from the store.
        let _ = (tasks.map { [$0.isCompleted ? 1 : 0, $0.droppedAt == nil ? 0 : 1, $0.effortMinutes ?? -1, Int($0.dueDate?.timeIntervalSince1970 ?? 0)] },
                 plans.map { $0.capacity },
                 anchors.map { [$0.attendanceStatus, $0.windowStart, $0.windowEnd] as [AnyHashable] },
                 habitEntries.map { [$0.amount, $0.completedAt == nil ? 0 : 1] }, habits.map { [$0.isArchived ? 1 : 0, $0.pausesData.count] as [AnyHashable] },
                 sessions.map { [$0.outcome, $0.actualSeconds] as [AnyHashable] }, settings.map { [$0.mediumDayMinutes, $0.rolloverMinute] })
        let overview = try? TodayDay.overview(in: context, now: now)
        let todayHabits = try? TodayHabits.read(
            in: context, now: now, boundary: TodayDay.boundary(in: context), firstWeekday: Calendar.current.firstWeekday)
        let anchorItems = (try? TodayAnchors.items(in: context, now: now, boundary: TodayDay.boundary(in: context))) ?? []
        let categories = TodayTaskFilter.options(allCategories)
        let filter = categories.first { $0.id == filterID }
        let boundary = TodayDay.boundary(in: context)
        let pickUps = FocusSessions.pickUpRows(tasks: tasks, today: boundary.logicalDate(at: now), boundary: boundary)
            .filter { !dismissedPickUps.contains($0.task.id) }
        let content: TodayContent? = overview.map { overview in
            TodayContent(
                remainingTasks: overview.shown.count, completedTasks: overview.completedToday.count, alsoToday: overview.alsoToday.count,
                anchors: anchorItems.count, pendingAnchors: anchorItems.filter(Self.isPending).count,
                habits: todayHabits?.total ?? 0, unfinishedHabits: (todayHabits?.total ?? 0) - (todayHabits?.done ?? 0))
        }
        let state = content.map(TodayState.of) ?? .normal
        let (morningNow, eveningNow) = promptClocks(boundary)
        let morningDue = morningNow.flatMap { try? MorningCard.isDue(now: $0, boundary: boundary, context: context) } ?? false
        let eveningDue = eveningNow.flatMap { try? NightPlanning.eveningPromptDue(now: $0, boundary: boundary, context: context) } ?? false
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                if let overview {
                    header(overview, categories: categories, filter: filter, state: state, unplanned: morningDue)
                    CapacityMeter(
                        plannedMinutes: overview.plannedMinutes, budgetMinutes: overview.budgetMinutes,
                        state: overview.state, loadScore: overview.loadScore, wholeDay: filter != nil
                    )
                    CapacitySlider(level: overview.level) { level in
                        try? TodayDay.setLevel(level, in: context, now: now)
                    }
                    if morningDue { morningCard }
                    ForEach(pickUps, id: \.task.id) { row in pickUpRow(row) }
                    anchorsSection(anchorItems)
                    habitsSection(todayHabits)
                    tasksSection(overview, filter: filter)
                    alsoToday(overview)
                    if eveningDue && state != .allDone { planTomorrowRow }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.row)
            .padding(.bottom, 120)                                          // clear of the floating tab bar
        }
        .scrollIndicators(.hidden)
        .onAppear {
            #if DEBUG
            if DebugLaunch.openAdd { isAdding = true }
            if let step = DebugLaunch.planStep, let flow = try? PlanningFlow(context: context, mode: .evening) {
                for _ in 1..<max(step, 1) { flow.next() }
                planning = flow
            }
            if DebugLaunch.openTask { openTask = tasks.first { $0.title == "Call the clinic back" } }
            #endif
        }
        .sheet(item: $openTask) { task in
            TaskDetailSheet(task: task)
        }
        .fullScreenCover(item: $planning) { flow in NightPlanningScreen(flow: flow) }
        .sheet(isPresented: $isAdding) {
            AddTaskSheet(today: TodayDay.boundary(in: context).logicalDate(at: now))
        }
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
        // The morning card is logged the first time it is shown (once a day).
        .task(id: morningDue) {
            if morningDue { try? MorningCard.markShown(now: promptClocks(boundary).morning ?? now, boundary: boundary, context: context) }
        }
        // A new day starts unfiltered.
        .onChange(of: overview?.today) { _, _ in filterID = nil; dismissedPickUps = [] }
    }

    private static func isPending(_ item: TodayAnchorItem) -> Bool {
        switch item {
        case .plain(let row): row.status == .pending
        case .group(let group): !group.isAllDecided
        }
    }

    private func header(_ overview: TodayOverview, categories: [TaskCategory], filter: TaskCategory?, state: TodayState, unplanned: Bool) -> some View {
        let headline = unplanned ? TodayCopy.unplanned(date: overview.today) : TodayCopy.headline(remaining: overview.shown.count)
        return VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            HStack(alignment: .center) {
                Text(TodayCopy.headerLabel(overview.today)).threadsType(.label).foregroundStyle(threads.ink2)
                Spacer()
                toolbar(categories: categories, isFiltering: filter != nil)
            }
            switch state {
            case .normal: DisplayHeadline(first: headline.first, second: headline.second)
            case .allDone:
                statement(TodayCopy.allDone)
                planTomorrowRow
            case .blank: statement(TodayCopy.blankDay)
            }
            if let filter {
                Button { filterID = nil } label: {
                    HStack(spacing: ThreadsSpace.tight) {
                        Circle().fill(JamaalPalette.categoryColor(forKey: filter.colorKey)).frame(width: 10, height: 10)
                        Text(filter.name).threadsType(.row).foregroundStyle(threads.ink)
                        Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(threads.ink2)
                    }
                    .padding(ThreadsSpace.chipPadding)
                    .frame(minHeight: ThreadsHit.minimum)
                    .overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Showing \(filter.name) tasks")
                .accessibilityHint("Shows all tasks")
                .accessibilityIdentifier("filterChip")
            }
        }
    }

    /// The instants the morning card and the evening row are judged at: now, except that debug runs can pretend (and
    /// in-memory test runs switch them off unless asked, so UI tests don't depend on the time of day).
    private func promptClocks(_ boundary: DayBoundary) -> (morning: Date?, evening: Date?) {
        #if DEBUG
        let today = boundary.logicalDate(at: now)
        return (
            DebugLaunch.morning ? boundary.instant(of: today, atMinute: 9 * 60) : (DebugLaunch.inMemory ? nil : now),
            DebugLaunch.evening ? boundary.instant(of: today, atMinute: 21 * 60) : (DebugLaunch.inMemory ? nil : now)
        )
        #else
        return (now, now)
        #endif
    }

    /// "Plan tomorrow ›": once everything is done, and quietly after the planning time if tonight isn't planned.
    private var planTomorrowRow: some View {
        Button(action: startPlanning) {
            HStack {
                Image(systemName: "moon")
                Text("Plan tomorrow").threadsType(.lede)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(threads.ink3)
            }
            .foregroundStyle(threads.ink)
            .frame(minHeight: ThreadsHit.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("planTomorrowRow")
    }

    /// TD-07: no plan was confirmed for today. Pick for today opens the shortened flow; Not now puts it away.
    private var morningCard: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            HStack(alignment: .top, spacing: ThreadsSpace.row) {
                CompanionMark()
                Text(TodayCopy.morningCard).threadsType(.lede).foregroundStyle(threads.ink)
            }
            HStack(spacing: ThreadsSpace.tight) {
                Button(action: pickForToday) {
                    Text("Pick for today").threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52).background(Capsule().fill(threads.terra))
                }
                .accessibilityIdentifier("pickForToday")
                PillButton(title: "Not now", fills: true) {
                    try? MorningCard.dismiss(now: now, boundary: TodayDay.boundary(in: context), context: context)
                    now = .now
                }
                .accessibilityIdentifier("morningNotNow")
            }
            .buttonStyle(.plain)
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(threads.line2, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("morningCard")
    }

    private func pickForToday() {
        try? MorningCard.dismiss(now: now, boundary: TodayDay.boundary(in: context), context: context)
        planning = try? PlanningFlow(context: context, mode: .morning)
    }

    /// Opens (or resumes) tonight's planning: tomorrow's plan, looking back at today.
    private func startPlanning() {
        planning = try? PlanningFlow(context: context, mode: .evening)
    }

    private func statement(_ text: String) -> some View {
        Text(text).threadsType(.display(.compact)).foregroundStyle(threads.ink2)
            .padding(.vertical, ThreadsSpace.section)
            .accessibilityAddTraits(.isHeader)
    }

    /// The glass capsule at the top right: the category filter, and Add. (Plan tomorrow's moon joins it with Night Planning.)
    private func toolbar(categories: [TaskCategory], isFiltering: Bool) -> some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Show tasks from", selection: $filterID) {
                    Text("All").tag(UUID?.none)
                    ForEach(categories, id: \.id) { category in Text(category.name).tag(Optional(category.id)) }
                }
            } label: {
                Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .font(.title3).frame(width: 52, height: 52)
            }
            .accessibilityLabel("Filter tasks by category")
            .accessibilityIdentifier("filterButton")
            Button(action: startPlanning) {
                Image(systemName: "moon").font(.title3).frame(width: 52, height: 52)
            }
            .accessibilityLabel("Plan tomorrow")
            .accessibilityIdentifier("planTomorrow")
            Button { isAdding = true } label: {
                Image(systemName: "plus").font(.title3).frame(width: 52, height: 52)
            }
            .accessibilityLabel("Add")
            .accessibilityIdentifier("addButton")
        }
        .buttonStyle(.plain)
        .foregroundStyle(threads.ink)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    /// TD-06: a session was closed at the rollover; offer to pick its task back up, or put the offer away.
    private func pickUpRow(_ row: PickUpRow) -> some View {
        let line = TodayCopy.pickUp(
            minutes: row.session.actualSeconds / 60, title: row.task.title,
            closedAt: TodayCopy.closeTime(rolloverMinute: settings.first?.rolloverMinute ?? 0))
        var text = AttributedString(line.before)
        var title = AttributedString(line.title); title.font = .custom("HankenGrotesk-SemiBold", size: 17)
        text.append(title); text.append(AttributedString(line.after))
        return VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Divider().overlay(threads.line)
            HStack(alignment: .top, spacing: ThreadsSpace.row) {
                Image(systemName: "clock").font(.title3).foregroundStyle(threads.ink).padding(.top, 2)
                Text(text).threadsType(.body).foregroundStyle(threads.ink)
            }
            HStack(spacing: ThreadsSpace.row) {
                PillButton(title: "Pick it back up") {
                    dismissedPickUps.insert(row.task.id)
                    focus.begin(.task(row.task))
                }
                Button("Dismiss") { dismissedPickUps.insert(row.task.id) }
                    .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                    .frame(minHeight: ThreadsHit.minimum)
            }
            .padding(.leading, 30)
            Divider().overlay(threads.line)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pickUpRow")
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
                    HabitGroupView(group: group, onAction: { row, action in log(action, on: row) }, onBegin: { focus.begin(.habit($0.window)) })
                }
                ForEach(Array(habits.rows.enumerated()), id: \.element.window.id) { index, row in
                    HabitRowView(row: row, onAction: { log($0, on: row) }, onBegin: { focus.begin(.habit(row.window)) })
                    if index < habits.rows.count - 1 { Divider().overlay(threads.line) }
                }
            }
        }
    }

    private func isTiming(_ task: TaskItem) -> Bool {
        FocusSessions.liveSession(in: context)?.task === task
    }

    private func log(_ action: HabitLogAction, on row: TodayHabitRow) {
        now = .now
        let today = TodayDay.boundary(in: context).logicalDate(at: now)
        try? HabitLogging.apply(action, to: row.window, on: today, now: now, context: context)
    }

    @ViewBuilder
    private func tasksSection(_ overview: TodayOverview, filter: TaskCategory?) -> some View {
        let rows = TodayTaskFilter.apply(overview.shown + overview.completedToday, to: filter)
        if !rows.isEmpty || filter != nil {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                SectionLabel(title: "Tasks")
                if rows.isEmpty, let filter {
                    HStack {
                        Text(TodayCopy.nothingIn(filter.name)).threadsType(.lede).foregroundStyle(threads.ink2)
                        Spacer()
                        Button("Show all") { filterID = nil }
                            .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                            .frame(minHeight: ThreadsHit.minimum)
                            .accessibilityIdentifier("showAll")
                    }
                }
                ForEach(rows, id: \.id) { task in
                    TaskRow(task: task, doneTime: task.completedAt.map(Self.timeFormat.string(from:)),
                            trackedSeconds: FocusSessions.trackedSeconds(of: task, at: now), isTiming: isTiming(task),
                            onToggle: { toggle(task) }, onOpen: { openTask = task })
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
                        TaskRow(task: task, doneTime: nil, trackedSeconds: FocusSessions.trackedSeconds(of: task, at: now), isTiming: isTiming(task),
                            onToggle: { toggle(task) }, onOpen: { openTask = task })
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
