//
//  PlanningSteps.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

// MARK: - 1 Review

/// How the day went, in plain counts: no verdicts, no mood.
struct ReviewStep: View {
    @Environment(\.threads) private var threads
    let flow: PlanningFlow
    let revision: Int

    var body: some View {
        let review = try? flow.review()
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            PlanningHeadline(headline: PlanningCopy.reviewHeadline(date: flow.reviewDate))
            if let review {
                VStack(spacing: 0) {
                    Divider().overlay(threads.line)
                    row("Tasks", PlanningCopy.tasksRow(done: review.doneCount, left: review.leftCount))
                    if let time = PlanningCopy.timeRow(
                        actualMinutes: review.totalActualMinutes,
                        estimatedMinutes: review.timeSpent.reduce(0) { $0 + ($1.estimateMinutes ?? 0) }) {
                        row("Time on tasks", time)
                    }
                    if let habits = PlanningCopy.habitsRow(done: review.habitsDone, due: review.habitsDue, partial: partialHabit(review)) {
                        row("Habits", habits)
                    }
                    if let anchors = anchorsRow(review) { row("Anchors", anchors) }
                }
                if !review.completedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                        SectionLabel(title: "Done")
                        ForEach(review.completedTasks, id: \.id) { task in
                            HStack(spacing: ThreadsSpace.row) {
                                Image(systemName: "checkmark").foregroundStyle(threads.accent).frame(width: 22)
                                Text(task.title).threadsType(.lede).foregroundStyle(threads.ink)
                                Spacer(minLength: ThreadsSpace.tight)
                                if let spent = review.timeSpent.first(where: { $0.task.id == task.id }) {
                                    Text(spent.estimateMinutes.map { "\(spent.actualMinutes) of \($0)" } ?? "\(spent.actualMinutes) min")
                                        .threadsType(.body).foregroundStyle(threads.ink2)
                                }
                            }
                            .frame(minHeight: 40)
                        }
                    }
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer(minLength: ThreadsSpace.row)
                Text(value).threadsType(.lede).foregroundStyle(threads.ink).multilineTextAlignment(.trailing)
            }
            .padding(.vertical, ThreadsSpace.row)
            Divider().overlay(threads.line)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Water 2 of 3": the first habit that was partly done.
    private func partialHabit(_ review: DayReview) -> String? {
        review.habits.first { $0.state == .partialLow || $0.state == .partialHigh }
            .map { "\($0.habit.title) \($0.amount) of \($0.target)" }
    }

    private func anchorsRow(_ review: DayReview) -> String? {
        let counting = review.anchors.filter { $0.status != .skipped && $0.status != .delegated }
        guard !counting.isEmpty else { return nil }
        let attended = counting.filter { $0.status == .attended }.count
        var text = "\(attended) of \(counting.count) attended"
        if let open = counting.first(where: { $0.status == .pending && $0.windowState != .closed && $0.windowState != .upcoming }) {
            text += " · \(open.anchor.title) open"
        }
        return text
    }
}

// MARK: - 2 Carry forward

/// What to do with what didn't happen: **Keep** (for tomorrow), **Later** (a day you pick) or **Drop**. Each choice
/// applies at once and can be undone until the day is closed.
struct CarryStep: View {
    @Environment(\.threads) private var threads
    let flow: PlanningFlow
    let revision: Int
    let bump: () -> Void
    @State private var laterOpen: Set<UUID> = []
    @State private var pickingDateFor: TaskItem?

    var body: some View {
        let items = flow.carryItems()
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                PlanningHeadline(headline: PlanningCopy.carryHeadline(count: items.count))
                Text("Keep it for tomorrow, move it, or let it go.").threadsType(.lede).foregroundStyle(threads.ink2)
            }
            ForEach(items, id: \.task.id) { item in
                itemView(item)
                Divider().overlay(threads.line)
            }
        }
        .sheet(item: $pickingDateFor) { task in DatePickSheet(title: task.title, earliest: flow.forDate.addingDays(1)) { date in
            apply(task, .later(date, .unspecified))
        } }
    }

    // MARK: One item

    private enum Choice { case keep, later, drop }

    private func choice(for item: CarryItem) -> Choice {
        if laterOpen.contains(item.task.id) { return .later }
        switch item.state {
        case .pending: return .keep                                            // tentative: applied on Continue
        case .dropped: return .drop
        case .moved(let to): return to == flow.forDate ? .keep : .later
        }
    }

    private func itemView(_ item: CarryItem) -> some View {
        let task = item.task
        let current = choice(for: item)
        return VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text(task.title).threadsType(.row).foregroundStyle(threads.ink)
            Text(PlanningCopy.carryMeta(effortMinutes: task.effortMinutes, deferrals: task.deferralCount))
                .threadsType(.meta).foregroundStyle(threads.ink2)
            segmented(current, task: task, item: item)
            if current == .later { laterOptions(task, item: item) }
            if case .moved = item.state, flow.canUndoCarry(task) { undoRow("Moved", task) }
            if case .dropped = item.state, flow.canUndoCarry(task) { undoRow("Dropped", task) }
        }
        .padding(.vertical, ThreadsSpace.hair)
        .accessibilityElement(children: .contain)
    }

    private func segmented(_ current: Choice, task: TaskItem, item: CarryItem) -> some View {
        HStack(spacing: 0) {
            segment("Keep", isOn: current == .keep, id: "keep-\(task.title)") {
                laterOpen.remove(task.id)
                if case .pending = item.state { apply(task, .keep) } else if current != .keep { undoThenKeep(task) }
            }
            segment("Later", isOn: current == .later, id: "later-\(task.title)") { laterOpen.insert(task.id) }
            segment("Drop", isOn: current == .drop, id: "drop-\(task.title)") { laterOpen.remove(task.id); apply(task, .drop) }
        }
        .padding(4)
        .background(Capsule().fill(threads.line))
    }

    private func segment(_ title: String, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).threadsType(isOn ? .row : .lede)
                .foregroundStyle(isOn ? threads.ink : threads.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(isOn ? threads.card : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func laterOptions(_ task: TaskItem, item: CarryItem) -> some View {
        let preview = TaskDeferral.preview(task, from: flow.reviewDate)
        let calendarFirst = Calendar.current.firstWeekday
        let options = QuickDates.options(
            today: flow.forDate, firstWeekday: calendarFirst == 1 ? 7 : calendarFirst - 1,
            importance: preview.somedayAllowed ? .low : .medium, repeating: false)
            .filter { $0.kind != .today && $0.kind != .tomorrow }
        return VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            if preview.requiresPicker {
                HStack(alignment: .top, spacing: ThreadsSpace.row) {
                    CompanionMark(size: 36)
                    Text(TaskDetailCopy.deferLine(preview) + (TaskDetailCopy.easeNote(preview).map { " " + $0.replacingOccurrences(of: " Someday is open now.", with: "") } ?? ""))
                        .threadsType(.body).foregroundStyle(threads.ink)
                }
            }
            FlowChips {
                ForEach(options, id: \.kind) { option in
                    Chip(title: option.kind == .someday ? "Someday" : AddTaskForm.dateTitle(option.date!).replacingOccurrences(of: " Oct", with: ""),
                         isSelected: isMoved(item, to: option.date)) { apply(task, .later(option.date, .unspecified)) }
                }
                Chip(title: "Date…", isSelected: false) { pickingDateFor = task }
            }
        }
    }

    private func isMoved(_ item: CarryItem, to date: CalendarDate?) -> Bool {
        if case .moved(let to) = item.state { return to == date }
        return false
    }

    private func undoRow(_ word: String, _ task: TaskItem) -> some View {
        HStack {
            Text(word).threadsType(.meta).foregroundStyle(threads.ink2)
            Spacer()
            Button("Undo") { flow.undoCarry(task); bump() }
                .threadsType(.meta).foregroundStyle(threads.ink).buttonStyle(.plain)
                .frame(minHeight: ThreadsHit.minimum)
        }
    }

    // MARK: Acting

    private func apply(_ task: TaskItem, _ choice: CarryChoice) {
        if flow.carry(task, choice) == .needsPicker { laterOpen.insert(task.id) }
        bump()
    }

    private func undoThenKeep(_ task: TaskItem) {
        flow.undoCarry(task)
        apply(task, .keep)
    }

    /// Anything left untouched is kept for tomorrow (a task on its third deferral goes to next week instead, since
    /// that one needs a day that works).
    static func settlePending(_ flow: PlanningFlow) {
        for item in flow.carryItems() {
            guard case .pending = item.state else { continue }
            if flow.carry(item.task, .keep) == .needsPicker {
                let calendarFirst = Calendar.current.firstWeekday
                let nextWeek = QuickDates.options(
                    today: flow.forDate, firstWeekday: calendarFirst == 1 ? 7 : calendarFirst - 1, importance: .medium, repeating: false)
                    .first { $0.kind == .nextWeek }?.date
                _ = flow.carry(item.task, .later(nextWeek ?? flow.forDate.addingDays(7), .unspecified))
            }
        }
    }
}

/// A date picker in a small sheet ("Date…").
struct DatePickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.threads) private var threads
    let title: String
    let onPick: (CalendarDate) -> Void
    let earliest: CalendarDate
    @State private var date: Date

    init(title: String, earliest: CalendarDate, onPick: @escaping (CalendarDate) -> Void) {
        self.title = title
        self.earliest = earliest
        self.onPick = onPick
        _date = State(initialValue: earliest.pickerDate())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            Text(title).threadsType(.display(.compact)).foregroundStyle(threads.ink)
            DatePicker("Date", selection: $date, in: earliest.pickerDate()..., displayedComponents: .date)
                .datePickerStyle(.graphical).labelsHidden()
            Button { onPick(CalendarDate(pickerDate: date)); dismiss() } label: {
                Text("Move here").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
        }
        .padding(ThreadsSpace.gutter)
        .background(threads.app)
        .presentationDetents([.large])
    }
}

// MARK: - 3 Build tomorrow

/// The shape of the planned day: its fixed commitments with the named gaps between them, its tasks (each can be
/// pushed out to the next day), what could come in, and its habits, read-only.
struct BuildStep: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    let flow: PlanningFlow
    let revision: Int
    let bump: () -> Void
    @State private var isAdding = false

    private var zone: TimeZone { flow.boundary.timeZone }

    var body: some View {
        let build = try? flow.build()
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                PlanningHeadline(headline: PlanningCopy.buildHeadline(date: flow.forDate))
                if let build {
                    Text(PlanningCopy.buildLede(
                        dayStartMinute: flow.settings.dayStartMinute, dayEndMinute: flow.settings.dayEndMinute,
                        freeMinutes: build.freeTime.freeMinutes))
                        .threadsType(.lede).foregroundStyle(threads.ink2)
                }
            }
            if let build {
                shape(build)
                tasks(build)
                couldComeIn(build)
                habits(build)
            }
        }
        .sheet(isPresented: $isAdding, onDismiss: bump) {
            AddTaskSheet(today: flow.boundary.logicalDate(at: .now), dueDate: flow.forDate)
        }
    }

    // MARK: The shape

    private enum Entry: Identifiable {
        case commitment(FreeTime.Commitment)
        case gap(FreeTime.Block, isLongest: Bool)
        var id: String {
            switch self {
            case .commitment(let c): "c-\(c.start.timeIntervalSince1970)-\(c.title)"
            case .gap(let b, _): "g-\(b.start.timeIntervalSince1970)"
            }
        }
        var start: Date {
            switch self {
            case .commitment(let c): c.start
            case .gap(let b, _): b.start
            }
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .current, timeZone: zone))
    }

    @ViewBuilder private func shape(_ build: PlanBuild) -> some View {
        let commitments = FreeTime.commitments(from: build.anchors).filter(\.isFixed)
        let longest = build.freeTime.longestBlockMinutes
        let entries = (commitments.map(Entry.commitment) + build.freeTime.visibleBlocks.map { Entry.gap($0, isLongest: $0.minutes == longest) })
            .sorted { $0.start < $1.start }
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            ForEach(entries) { entry in
                switch entry {
                case .commitment(let c):
                    HStack(alignment: .firstTextBaseline, spacing: ThreadsSpace.row) {
                        Text(time(c.start)).threadsType(.label).foregroundStyle(threads.ink2).frame(width: 56, alignment: .leading)
                        Rectangle().fill(threads.deep).frame(width: 3, height: 22)
                        Text(c.minutes >= 30 ? "\(c.title) · until \(time(c.start.addingTimeInterval(Double(c.minutes) * 60)))" : c.title)
                            .threadsType(.row).foregroundStyle(threads.ink)
                    }
                case .gap(let block, let isLongest):
                    Text(gapLine(block, isLongest: isLongest))
                        .threadsType(.meta).foregroundStyle(threads.ink2)
                        .padding(.leading, 56 + ThreadsSpace.row + 3 + ThreadsSpace.row)
                        .padding(.bottom, ThreadsSpace.hair)
                }
            }
            Button { isAdding = true } label: {
                Label("Add a task", systemImage: "plus").threadsType(.row).foregroundStyle(threads.ink)
                    .frame(minHeight: ThreadsHit.minimum, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("buildAddTask")
        }
    }

    private func gapLine(_ block: FreeTime.Block, isLongest: Bool) -> String {
        var line = "\(TodayCopy.duration(block.minutes)) free"
        if let after = block.after { line += " · after \(after)" }
        else if let before = block.before { line += " · before \(before)" }
        else { line += " · until \(PlanningCopy.clock(flow.settings.dayEndMinute))" }
        if isLongest { line += " · longest" }
        return line
    }

    // MARK: Tasks

    @ViewBuilder private func tasks(_ build: PlanBuild) -> some View {
        let tasksMinutes = build.tasks.reduce(0) { $0 + ($1.effortMinutes ?? 0) }
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            SectionLabel(title: "Tasks for \(PlanningCopy.weekday(flow.forDate)) · \(TodayCopy.duration(tasksMinutes))")
            if build.tasks.isEmpty {
                Text("Nothing yet. Pick something below, or leave it open.").threadsType(.lede).foregroundStyle(threads.ink2)
            }
            ForEach(build.tasks, id: \.id) { task in
                HStack(spacing: ThreadsSpace.row) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title).threadsType(.row).foregroundStyle(threads.ink)
                        Text(taskMeta(task, build: build)).threadsType(.meta).foregroundStyle(threads.ink2)
                    }
                    Spacer(minLength: ThreadsSpace.tight)
                    Button { flow.pushOut(task); bump() } label: {
                        Image(systemName: "arrow.right").font(.body).foregroundStyle(threads.ink)
                            .frame(width: 44, height: 44).overlay(Circle().strokeBorder(threads.line2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Move \(task.title) to \(PlanningCopy.weekday(flow.forDate.addingDays(1)))")
                }
                .padding(.vertical, ThreadsSpace.hair)
                Divider().overlay(threads.line)
            }
        }
    }

    private func taskMeta(_ task: TaskItem, build: PlanBuild) -> String {
        var parts: [String] = []
        if let minutes = task.effortMinutes { parts.append(TodayCopy.duration(minutes)) }
        if build.doesNotFit.contains(where: { $0.id == task.id }) { parts.append("longer than any gap") }
        if task.deferralCount > 0 && task.dueDate == flow.forDate.storedDate { parts.append("kept from today") }
        if let name = task.category?.name, !name.isEmpty { parts.append(name) }
        return parts.joined(separator: " · ")
    }

    // MARK: Could come in, and habits

    @ViewBuilder private func couldComeIn(_ build: PlanBuild) -> some View {
        let planned = Set(build.tasks.map(\.id))
        let candidates = (build.scheduleSuggestions + build.backlogCandidates).filter { !planned.contains($0.id) }
        let unique = candidates.reduce(into: [TaskItem]()) { list, task in if !list.contains(where: { $0.id == task.id }) { list.append(task) } }
        if !unique.isEmpty {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                SectionLabel(title: "Could come in")
                ForEach(unique.prefix(3), id: \.id) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title).threadsType(.row).foregroundStyle(threads.ink)
                            Text([task.effortMinutes.map(TodayCopy.duration), task.dueDate == nil ? "from the backlog" : "important, not urgent"]
                                .compactMap { $0 }.joined(separator: " · "))
                                .threadsType(.meta).foregroundStyle(threads.ink2)
                        }
                        Spacer(minLength: ThreadsSpace.tight)
                        PillButton(title: "+ \(PlanningCopy.weekday(flow.forDate))") { flow.pullIn(task); bump() }
                            .accessibilityLabel("Add \(task.title) to \(PlanningCopy.weekday(flow.forDate))")
                    }
                }
            }
        }
    }

    @ViewBuilder private func habits(_ build: PlanBuild) -> some View {
        if !build.habitWindows.isEmpty {
            let minutes = HabitToday.remainingMinutes(build.habitWindows)
            HStack(alignment: .firstTextBaseline) {
                Text("Habits on \(PlanningCopy.weekday(flow.forDate))").threadsType(.lede).foregroundStyle(threads.ink2)
                Spacer(minLength: ThreadsSpace.row)
                Text(build.habitWindows.map(\.habit.title).joined(separator: " · ") + (minutes > 0 ? " · \(minutes) min" : ""))
                    .threadsType(.lede).foregroundStyle(threads.ink).multilineTextAlignment(.trailing)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - 4 Check the load

/// The planned day's level (written the moment it is chosen), the meter, and the one specific suggestion when the
/// day is too much. Nothing here refuses anything.
struct LoadStep: View {
    @Environment(\.threads) private var threads
    let flow: PlanningFlow
    let revision: Int
    let bump: () -> Void

    var body: some View {
        let check = try? flow.loadCheck()
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            if let check {
                PlanningHeadline(headline: PlanningCopy.loadHeadline(check.state))
                CapacitySlider(level: check.level, details: details) { level in flow.setLevel(level); bump() }
                Text(PlanningCopy.levelLine(
                    date: flow.forDate, usual: flow.settings.defaultLevel(forISOWeekday: flow.forDate.isoWeekday),
                    freeMinutes: (try? flow.build().freeTime.freeMinutes) ?? 0, suggested: check.suggestedLevel))
                    .threadsType(.lede).foregroundStyle(threads.ink2)
                CapacityMeter(plannedMinutes: check.plannedMinutes, budgetMinutes: check.budgetMinutes, state: check.state, loadScore: check.loadScore)
                if check.overflowMinutes > 0 {
                    Text(PlanningCopy.overflow(minutes: check.overflowMinutes, dayEndMinute: flow.settings.dayEndMinute))
                        .threadsType(.meta).foregroundStyle(threads.terra)
                }
                if let suggestion = check.moveSuggestion { suggestionCard(suggestion) }
                if check.missingDurations > 0 {
                    Text(check.missingDurations == 1 ? "One task has no estimate, so it isn't counted." : "\(check.missingDurations) tasks have no estimate, so they aren't counted.")
                        .threadsType(.meta).foregroundStyle(threads.ink2)
                }
            }
        }
    }

    private var details: [CapacityLevel: String] {
        let medium = flow.settings.mediumDayMinutes
        return Dictionary(uniqueKeysWithValues: TodayCopy.levels.map { level in
            (level, TodayCopy.duration(CapacityLoad.budgetMinutes(for: level, mediumDayMinutes: medium)).uppercased())
        })
    }

    private func suggestionCard(_ suggestion: MoveSuggestion) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            HStack(alignment: .top, spacing: ThreadsSpace.row) {
                CompanionMark()
                Text(PlanningCopy.moveOffer(title: suggestion.task.title, target: suggestion.target, today: flow.forDate))
                    .threadsType(.lede).foregroundStyle(threads.ink)
            }
            HStack(spacing: ThreadsSpace.tight) {
                if suggestion.target != nil {
                    Button { flow.moveSuggested(suggestion); bump() } label: {
                        Text(PlanningCopy.moveButton(target: suggestion.target)).threadsType(.row).foregroundStyle(threads.ink)
                            .frame(maxWidth: .infinity, minHeight: 48).overlay(Capsule().strokeBorder(threads.ink, lineWidth: 1.2))
                    }
                    .accessibilityIdentifier("moveSuggested")
                }
                PillButton(title: "Keep as planned", fills: true) {}
            }
            .buttonStyle(.plain)
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(threads.line2, lineWidth: 1))
    }
}

// MARK: - 5 Close the day

/// "Tomorrow is ready." on `deep`, with a plain count of nights planned. No streak, no score.
struct CloseStep: View {
    @Environment(\.threads) private var threads
    let flow: PlanningFlow
    let summary: ClosingSummary
    let firstAnchor: String?
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("5 OF 5 · \(PlanningCopy.weekday(flow.forDate).uppercased())").threadsType(.label).foregroundStyle(threads.onDeep.opacity(0.7))
            Text("Tomorrow is ready.").threadsType(.display(.large)).foregroundStyle(threads.onDeep)
                .padding(.top, ThreadsSpace.tight).accessibilityAddTraits(.isHeader)
            Text(PlanningCopy.closeLine(tasks: summary.taskCount, minutes: summary.plannedMinutes, firstAnchor: firstAnchor))
                .threadsType(.lede).foregroundStyle(threads.onDeep.opacity(0.8))
                .padding(.top, ThreadsSpace.row)
            Divider().overlay(threads.onDeep.opacity(0.25)).padding(.vertical, ThreadsSpace.row)
            Text(PlanningCopy.nightsPlanned(summary.nightsPlanned)).threadsType(.body).foregroundStyle(threads.onDeep.opacity(0.7))
            Spacer()
            Button(action: onDone) {
                Text("Good night").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("goodNight")
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.bottom, ThreadsSpace.tight)
    }
}
