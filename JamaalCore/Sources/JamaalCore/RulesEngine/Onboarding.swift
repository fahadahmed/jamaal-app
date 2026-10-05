import Foundation
import SwiftData

/// The first-launch screens (docs/journeys/onboarding.md): OB-01 … OB-09.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case meet, idea, icloud, normalDay, reminders, task, habit, anchor, ready

    /// Steps the user may pass by (*Not now*): a non-Muslim user with no school run shouldn't have to invent an Anchor, and
    /// reminders can be turned on later.
    public var isSkippable: Bool { self == .reminders || self == .anchor }
}

public enum OnboardingError: Error, Equatable, Sendable {
    case timeOutOfRange
    case notAFirstHabit
}

/// A way to make the first habit: the presets, two gentle extras, and a bare name.
public struct OnboardingHabitChoice: Equatable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    /// Needs the user to type a name (*Something else*).
    public var needsName: Bool
}

/// When the first task is due: today, or tomorrow (the only two choices, so Today is never empty on first use).
public enum OnboardingDay: Sendable { case today, tomorrow }

/// Module 8's neighbour: what onboarding writes, and the rules that keep it honest.
public enum Onboarding {

    /// Onboarding shows until `onboardingCompletedAt` is set. That field syncs, so a second device on the same account
    /// sees *Welcome back* and skips to Today rather than starting again. No settings row yet means launch isn't done.
    public static func isNeeded(_ settings: UserSettings?) -> Bool {
        guard let settings else { return false }
        return settings.onboardingCompletedAt == nil
    }

    // MARK: Order

    /// The screens in order. The iCloud step appears only when iCloud isn't available (it is silent when all is well).
    public static func steps(icloudAvailable: Bool) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { icloudAvailable ? $0 != .icloud : true }
    }

    public static func next(after step: OnboardingStep, icloudAvailable: Bool) -> OnboardingStep? {
        let order = steps(icloudAvailable: icloudAvailable)
        guard let index = order.firstIndex(of: step), index + 1 < order.count else { return nil }
        return order[index + 1]
    }

    public static func previous(before step: OnboardingStep, icloudAvailable: Bool) -> OnboardingStep? {
        let order = steps(icloudAvailable: icloudAvailable)
        guard let index = order.firstIndex(of: step), index > 0 else { return nil }
        return order[index - 1]
    }

    // MARK: Your normal day (OB-04)

    /// The normal day, when the working day ends, and how today feels. Nothing is written if any part is refused: the
    /// working day keeps its start and needs two hours; today's level touches only today's plan, never the weekday defaults.
    @MainActor
    public static func saveNormalDay(
        minutes: Int, dayEnd: Int, level: CapacityLevel, settings: UserSettings, in context: ModelContext, now: Date,
        timeZone: TimeZone = .current
    ) throws {
        guard DaySettings.normalDayRange.contains(minutes), minutes % DaySettings.normalDayStep == 0 else { throw SettingsError.normalDayOutOfRange }
        guard (1..<1440).contains(dayEnd), dayEnd - settings.dayStartMinute >= DaySettings.minimumWorkingDayMinutes else { throw SettingsError.workingDayInvalid }
        try DaySettings.setNormalDay(minutes, on: settings)
        try DaySettings.setWorkingDay(start: settings.dayStartMinute, end: dayEnd, on: settings)
        try TodayDay.setLevel(level, in: context, now: now, timeZone: timeZone)
    }

    // MARK: When to speak (OB-05)

    /// The evening planning and morning list times: synced, so a second device starts with them.
    public static func saveTimes(planning: Int, morning: Int, settings: UserSettings) throws {
        guard (0..<1440).contains(planning), (0..<1440).contains(morning) else { throw OnboardingError.timeOutOfRange }
        settings.planningMinute = planning
        settings.morningMinute = morning
    }

    // MARK: The first task, habit and Anchor (OB-06 … OB-08)

    /// A low-importance task due today or tomorrow, with an optional label.
    @MainActor
    @discardableResult
    public static func createFirstTask(
        title: String, category: TaskCategory?, day: OnboardingDay, in context: ModelContext, now: Date, timeZone: TimeZone = .current
    ) throws -> TaskItem {
        let boundary = DayBoundary(rolloverMinute: (try? context.fetch(FetchDescriptor<UserSettings>()).first?.rolloverMinute) ?? 0, timeZone: timeZone)
        let today = boundary.logicalDate(at: now)
        var draft = TaskDraft(title: title)
        draft.importance = .low
        draft.dueDate = day == .today ? today : today.addingDays(1)
        draft.category = category
        return try TaskCreation.create(draft, in: context, now: now, timeZone: timeZone)
    }

    /// The first habit's choices, in the order shown: three that start well, a gentle extra, and a bare name.
    public static let habitChoices: [OnboardingHabitChoice] = [
        OnboardingHabitChoice(id: "quran", title: "Qur'an reading", subtitle: "15 minutes a day", needsName: false),
        OnboardingHabitChoice(id: "water", title: "Water", subtitle: "8 glasses a day", needsName: false),
        OnboardingHabitChoice(id: "walk", title: "A walk", subtitle: "20 minutes, three times a week", needsName: false),
        OnboardingHabitChoice(id: "dhikr", title: "Dhikr", subtitle: "33 a day", needsName: false),
        OnboardingHabitChoice(id: "other", title: "Something else", subtitle: "Just a name, once a day", needsName: true),
    ]

    /// The editable draft behind a choice. The presets keep their `presetKey`; *Water* and *A walk* are plain drafts, and
    /// *Something else* is a binary daily habit with just the name given.
    public static func habitDraft(for choice: String, name: String = "") -> HabitDraft? {
        switch choice {
        case "quran": return HabitDraft.preset(.quran)
        case "dhikr": return HabitDraft.preset(.dhikr)
        case "water":
            var draft = HabitDraft(kind: .counted)
            draft.title = "Water"
            draft.windows[0].target = 8
            return draft
        case "walk":
            var draft = HabitDraft(kind: .timed)
            draft.title = "A walk"
            draft.windows[0].target = 20
            draft.windows[0].effortMinutes = 20
            draft.perWeek = 3
            return draft
        case "other":
            var draft = HabitDraft(kind: .binary)
            draft.title = name
            return draft
        default: return nil
        }
    }

    @MainActor
    @discardableResult
    public static func createFirstHabit(choice: String, name: String = "", in context: ModelContext, now: Date) throws -> Habit {
        guard let draft = habitDraft(for: choice, name: name) else { throw OnboardingError.notAFirstHabit }
        return try HabitEditing.create(draft, in: context, now: now)
    }

    // MARK: Ready (OB-09)

    /// Marks onboarding done (once: a later call never moves the date).
    public static func complete(_ settings: UserSettings, now: Date) {
        if settings.onboardingCompletedAt == nil { settings.onboardingCompletedAt = now }
    }

    /// "Tonight, we'll plan tomorrow.": the quiet card on the first Today, shown while it is still the day onboarding
    /// finished and tomorrow has no Night Planning session. Derived; nothing is stored.
    @MainActor
    public static func tonightCardVisible(settings: UserSettings?, now: Date, boundary: DayBoundary, context: ModelContext) throws -> Bool {
        guard let done = settings?.onboardingCompletedAt else { return false }
        let today = boundary.logicalDate(at: now)
        guard boundary.logicalDate(at: done) == today else { return false }
        let tomorrow = today.addingDays(1)
        let planned = try context.fetch(FetchDescriptor<NightPlanningSession>()).contains { CalendarDate(storedDate: $0.forDate) == tomorrow }
        return !planned
    }
}
