//
//  OnboardingFlow.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// First launch (OB-01 … OB-09), over the shell until `onboardingCompletedAt` is set. Reminders and the Anchor can be
/// passed by; everything else needs a real answer, so Today is never empty. The saves are the engine's (`Onboarding`).
struct OnboardingFlow: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(ReminderCenter.self) private var reminders
    @Query(sort: \UserSettings.createdAt) private var rows: [UserSettings]
    @Query(sort: \TaskCategory.sortOrder) private var categories: [TaskCategory]

    @State private var step: OnboardingStep
    @State private var madeTask = 0
    @State private var madeHabit = 0
    @State private var madeAnchor = 0
    @State private var message: String?
    @State private var addingAnchor: AnchorChoice?
    @SwiftUI.FocusState private var focused: Bool

    // OB-04
    @State private var minutes = 180
    @State private var dayEnd = 19 * 60
    @State private var level: CapacityLevel = .medium
    // OB-05
    @State private var planning = 20 * 60
    @State private var morning = 7 * 60 + 30
    // OB-06
    @State private var title = ""
    @State private var categoryID: UUID?
    @State private var day: OnboardingDay = .today
    // OB-07
    @State private var habitID = "quran"
    @State private var habitName = ""

    private let icloudAvailable = FileManager.default.ubiquityIdentityToken != nil

    init(startAt step: OnboardingStep = .meet) { _step = State(initialValue: step) }

    private enum AnchorChoice: String, Identifiable { case prayer, schoolRun, binNight, plantWatering, custom; var id: String { rawValue } }

    private var settings: UserSettings? { rows.first }
    private var today: CalendarDate { TodayDay.boundary(in: context).logicalDate(at: .now) }

    var body: some View {
        NavigationStack {
            ZStack {
                (step == .ready ? threads.deep : threads.app).ignoresSafeArea()
                content
                    .padding(.horizontal, ThreadsSpace.gutter)
                    .padding(.top, 72).padding(.bottom, ThreadsSpace.section)
                    .id(step)
                    .transition(.opacity)
            }
            .overlay(alignment: .topLeading) { if Onboarding.previous(before: step, icloudAvailable: icloudAvailable) != nil { back } }
            .navigationDestination(item: $addingAnchor) { choice in anchorForm(choice) }
            .hidesNavigationBar()
        }
        .onAppear { primeFromSettings() }
        .interactiveDismissDisabled()
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        switch step {
        case .meet: meet
        case .idea: idea
        case .icloud: icloud
        case .normalDay: normalDay
        case .reminders: remindersStep
        case .task: firstTask
        case .habit: firstHabit
        case .anchor: firstAnchor
        case .ready: ready
        }
    }

    private var back: some View {
        Button {
            withAnimation(.snappy) { message = nil; step = Onboarding.previous(before: step, icloudAvailable: icloudAvailable) ?? step }
        } label: {
            Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(step == .ready ? threads.onDeep : threads.ink)
                .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
        }
        .buttonStyle(.plain).accessibilityLabel("Back").accessibilityIdentifier("onboardingBack")
        .padding(.leading, ThreadsSpace.row).padding(.top, ThreadsSpace.hair)
    }

    private func advance() {
        message = nil
        withAnimation(.snappy) { step = Onboarding.next(after: step, icloudAvailable: icloudAvailable) ?? step }
    }

    private func headline(_ text: String, eyebrow: String? = nil, subtitle: String? = nil, accent: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            if let eyebrow { Text(eyebrow).threadsType(.label).foregroundStyle(threads.ink2) }
            Group {
                if let accent {
                    Text(text) + Text("\n") + Text(accent).italic().foregroundStyle(threads.accent)
                } else { Text(text) }
            }
            .threadsType(.display(.compact)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).threadsType(.lede).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.tight) }
        }
    }

    private func primary(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).threadsType(.row).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private func secondary(_ title: String, id: String, outlined: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).threadsType(.row).foregroundStyle(threads.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay { if outlined { Capsule().strokeBorder(threads.line2, lineWidth: 1) } }.contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private var errorLine: some View {
        Group {
            if let message { Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("onboardingMessage") }
        }
    }

    // OB-01
    private var meet: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            Spacer()
            CompanionMark(size: 64)
            Text(OnboardingCopy.hello).threadsType(.display(.large)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
            Text(OnboardingCopy.helloBody).threadsType(.lede).foregroundStyle(threads.ink2)
            Spacer()
            primary("Begin", id: "onboardingBegin") { advance() }
        }
    }

    // OB-02
    private var idea: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            headline(OnboardingCopy.ideaTitle, accent: OnboardingCopy.ideaAccent)
            VStack(alignment: .leading, spacing: 0) {
                Divider().overlay(threads.line)
                ForEach(OnboardingCopy.ideaRows, id: \.title) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).threadsType(.row).foregroundStyle(threads.ink)
                        Text(row.detail).threadsType(.body).foregroundStyle(threads.ink2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    Divider().overlay(threads.line)
                }
            }
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                Text("NOT HERE").threadsType(.label).foregroundStyle(threads.ink2)
                Text(OnboardingCopy.notHere).threadsType(.lede).foregroundStyle(threads.ink)
            }
            Text(OnboardingCopy.iCloudLine).threadsType(.body).foregroundStyle(threads.ink2)
            Spacer()
            primary("Continue", id: "onboardingContinue") { advance() }
        }
    }

    // OB-03: only when iCloud isn't available
    private var icloud: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            headline(OnboardingCopy.iCloudTitle, subtitle: OnboardingCopy.iCloudBody)
            Spacer()
            primary("Continue", id: "onboardingContinue") { advance() }
        }
    }

    // OB-04
    private var normalDay: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            headline(OnboardingCopy.dayTitle, subtitle: OnboardingCopy.daySubtitle)
            HStack(spacing: ThreadsSpace.section) {
                Spacer()
                roundButton("minus", label: "Less", id: "dayLess", enabled: minutes > DaySettings.normalDayRange.lowerBound) { minutes -= DaySettings.normalDayStep }
                ThreadsNumeral(TodayCopy.duration(minutes), size: .large).foregroundStyle(threads.ink)
                    .frame(minWidth: 120).accessibilityLabel(TodayCopy.duration(minutes)).accessibilityIdentifier("dayMinutes")
                roundButton("plus", label: "More", id: "dayMore", enabled: minutes < DaySettings.normalDayRange.upperBound) { minutes += DaySettings.normalDayStep }
                Spacer()
            }
            VStack(spacing: 0) {
                Divider().overlay(threads.line)
                HStack {
                    Text(OnboardingCopy.dayEnds).threadsType(.lede).foregroundStyle(threads.ink)
                    Spacer()
                    DatePicker(OnboardingCopy.dayEnds, selection: Binding(get: { HabitForm.date(forMinute: dayEnd) }, set: { dayEnd = HabitForm.minute(of: $0) }),
                               displayedComponents: .hourAndMinute).labelsHidden().accessibilityIdentifier("dayEnd")
                }
                .frame(minHeight: 60)
                Divider().overlay(threads.line)
            }
            VStack(alignment: .leading, spacing: ThreadsSpace.row) {
                Text(OnboardingCopy.todayFeels).threadsType(.lede).foregroundStyle(threads.ink)
                CapacitySlider(level: level, details: levelDetails) { level = $0 }
            }
            errorLine
            Spacer()
            primary("Continue", id: "onboardingContinue", action: saveNormalDay)
        }
    }

    private var levelDetails: [CapacityLevel: String] {
        Dictionary(uniqueKeysWithValues: [CapacityLevel.low, .medium, .high].map {
            ($0, TodayCopy.duration(CapacityLoad.budgetMinutes(for: $0, mediumDayMinutes: minutes)).uppercased())
        })
    }

    private func roundButton(_ symbol: String, label: String, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3).foregroundStyle(threads.ink).frame(width: 56, height: 56)
                .background(Circle().fill(threads.card)).overlay(Circle().strokeBorder(threads.line2, lineWidth: 1)).contentShape(Circle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(label).accessibilityIdentifier(id)
    }

    // OB-05
    private var remindersStep: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            headline(OnboardingCopy.speakTitle, subtitle: OnboardingCopy.speakBody)
            VStack(spacing: 0) {
                Divider().overlay(threads.line)
                timeRow("Evening planning", minute: $planning, id: "planningTime")
                timeRow("Morning list", minute: $morning, id: "morningTime")
            }
            errorLine
            Spacer()
            primary("Allow notifications", id: "onboardingAllow") { allowNotifications() }
            secondary("Not now", id: "onboardingNotNow") { saveTimesAndAdvance(ask: false) }
        }
    }

    private func timeRow(_ title: String, minute: Binding<Int>, id: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink)
                Spacer()
                DatePicker(title, selection: Binding(get: { HabitForm.date(forMinute: minute.wrappedValue) }, set: { minute.wrappedValue = HabitForm.minute(of: $0) }),
                           displayedComponents: .hourAndMinute).labelsHidden().accessibilityIdentifier(id)
            }
            .frame(minHeight: 60)
            Divider().overlay(threads.line)
        }
    }

    // OB-06
    private var firstTask: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            headline(OnboardingCopy.taskTitle, eyebrow: OnboardingCopy.taskEyebrow)
            TextField(OnboardingCopy.taskPlaceholder, text: $title).threadsType(.lede).foregroundStyle(threads.ink)
                .focused($focused).submitLabel(.done).onSubmit { focused = false }
                .padding(.bottom, ThreadsSpace.tight).overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                .accessibilityIdentifier("firstTaskTitle")
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                Text(OnboardingCopy.labelEyebrow).threadsType(.label).foregroundStyle(threads.ink2)
                FlowChips {
                    ForEach(categories.filter { !$0.isArchived }, id: \.id) { category in
                        Chip(title: category.name, isSelected: categoryID == category.id) { categoryID = categoryID == category.id ? nil : category.id }
                            .accessibilityIdentifier("firstTaskCategory-\(category.name)")
                    }
                }
                Text(OnboardingCopy.labelNote).threadsType(.body).foregroundStyle(threads.ink2)
            }
            Picker("When", selection: $day) {
                Text("Today").tag(OnboardingDay.today)
                Text("Tomorrow").tag(OnboardingDay.tomorrow)
            }
            .pickerStyle(.segmented).accessibilityIdentifier("firstTaskDay")
            errorLine
            Spacer()
            primary("Add it", id: "onboardingAddTask", action: addTask)
        }
    }

    // OB-07
    private var firstHabit: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            headline(OnboardingCopy.habitTitle, eyebrow: OnboardingCopy.habitEyebrow)
            VStack(spacing: 0) {
                ForEach(Onboarding.habitChoices, id: \.id) { choice in
                    Button { habitID = choice.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.title).threadsType(.row).foregroundStyle(threads.ink)
                                Text(choice.subtitle).threadsType(.body).foregroundStyle(threads.ink2)
                            }
                            Spacer()
                            if habitID == choice.id { Image(systemName: "checkmark").foregroundStyle(threads.ink) }
                        }
                        .padding(ThreadsSpace.row).frame(maxWidth: .infinity, minHeight: 68, alignment: .leading).contentShape(Rectangle())
                        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(habitID == choice.id ? threads.card : .clear))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("habitChoice-\(choice.id)")
                    .accessibilityAddTraits(habitID == choice.id ? .isSelected : [])
                    Divider().overlay(threads.line).opacity(habitID == choice.id ? 0 : 1)
                }
            }
            if Onboarding.habitChoices.first(where: { $0.id == habitID })?.needsName == true {
                TextField("What is it?", text: $habitName).threadsType(.lede).foregroundStyle(threads.ink)
                    .focused($focused).submitLabel(.done).onSubmit { focused = false }
                    .padding(.bottom, ThreadsSpace.tight).overlay(alignment: .bottom) { Divider().overlay(threads.line2) }
                    .accessibilityIdentifier("firstHabitName")
            }
            errorLine
            Spacer()
            primary(OnboardingCopy.addHabitButton(Onboarding.habitChoices.first { $0.id == habitID }?.title ?? "habit"), id: "onboardingAddHabit", action: addHabit)
        }
    }

    // OB-08
    private var firstAnchor: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            headline(OnboardingCopy.anchorTitle, eyebrow: OnboardingCopy.anchorEyebrow, subtitle: OnboardingCopy.anchorBody)
            FlowChips {
                ForEach([("Prayer times", AnchorChoice.prayer), ("School run", .schoolRun), ("Bin night", .binNight), ("Plant watering", .plantWatering), ("Something else", .custom)], id: \.1) { item in
                    Chip(title: item.0, isSelected: false) { addingAnchor = item.1 }.accessibilityIdentifier("anchorChoice-\(item.1.rawValue)")
                }
            }
            Spacer()
            secondary("Not now", id: "onboardingAnchorNotNow", outlined: true) { advance() }
        }
    }

    @ViewBuilder private func anchorForm(_ choice: AnchorChoice) -> some View {
        switch choice {
        case .prayer:
            PrayerFormScreen(draft: PrayerRuleDraft(countryCode: nil), editing: nil, onFinished: { madeAnchor += 1; addingAnchor = nil; advance() })
        case .schoolRun:
            AnchorFormScreen(draft: AnchorRuleDraft.preset(.schoolRun, today: today), editing: nil, onFinished: { madeAnchor += 1; addingAnchor = nil; advance() })
        case .binNight:
            AnchorFormScreen(draft: AnchorRuleDraft.preset(.binNight, today: today), editing: nil, onFinished: { madeAnchor += 1; addingAnchor = nil; advance() })
        case .plantWatering:
            AnchorFormScreen(draft: AnchorRuleDraft.preset(.plantWatering, today: today), editing: nil, onFinished: { madeAnchor += 1; addingAnchor = nil; advance() })
        case .custom:
            AnchorFormScreen(draft: AnchorRuleDraft.preset(.custom, today: today), editing: nil, onFinished: { madeAnchor += 1; addingAnchor = nil; advance() })
        }
    }

    // OB-09
    private var ready: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            Spacer()
            Text(OnboardingCopy.readyTitle).threadsType(.display(.compact)).foregroundStyle(threads.onDeep).accessibilityAddTraits(.isHeader)
            Text(OnboardingCopy.readyBody(tasks: madeTask, habits: madeHabit, anchors: madeAnchor)).threadsType(.lede).foregroundStyle(threads.onDeep.opacity(0.75))
                .accessibilityIdentifier("readyBody")
            Divider().overlay(threads.onDeep.opacity(0.2))
            Text(OnboardingCopy.trial).threadsType(.body).foregroundStyle(threads.onDeep.opacity(0.75))
            Spacer()
            primary("Open Today", id: "onboardingOpenToday", action: finish)
        }
    }

    // MARK: Saves

    private func primeFromSettings() {
        guard let settings else { return }
        minutes = settings.mediumDayMinutes
        dayEnd = settings.dayEndMinute
        planning = settings.planningMinute
        morning = settings.morningMinute
        level = settings.defaultLevel(forISOWeekday: today.isoWeekday)
    }

    private func run(_ work: () throws -> Void) -> Bool {
        do { try work(); message = nil; return true }
        catch { message = OnboardingCopy.message(for: error); return false }
    }

    private func saveNormalDay() {
        guard let settings else { return }
        if run({ try Onboarding.saveNormalDay(minutes: minutes, dayEnd: dayEnd, level: level, settings: settings, in: context, now: .now) }) { advance() }
    }

    private func allowNotifications() { saveTimesAndAdvance(ask: true) }

    private func saveTimesAndAdvance(ask: Bool) {
        guard let settings else { return }
        guard run({ try Onboarding.saveTimes(planning: planning, morning: morning, settings: settings) }) else { return }
        Task {
            if ask { reminders.remindersOnThisDevice = true; await reminders.requestPermission() }
            reminders.scheduleReplan(in: context)
            advance()
        }
    }

    private func addTask() {
        let category = categories.first { $0.id == categoryID }
        if run({ try Onboarding.createFirstTask(title: title, category: category, day: day, in: context, now: .now) }) { madeTask += 1; advance() }
    }

    private func addHabit() {
        if run({ try Onboarding.createFirstHabit(choice: habitID, name: habitName, in: context, now: .now) }) { madeHabit += 1; advance() }
    }

    private func finish() {
        guard let settings else { return }
        Onboarding.complete(settings, now: .now)
        AppEngine.syncAnchors(in: context)
        reminders.scheduleReplan(in: context)
    }
}
