//
//  DebugLaunch.swift
//  Jamaal
//

#if DEBUG
import Foundation
import SwiftData
import JamaalCore

/// Launch arguments for UI tests and previews, in debug builds only: `-JamaalInMemory` keeps the store out of
/// the app's real data, `-JamaalSampleData` adds a few tasks, Anchors and habits for today, and `-JamaalOpenAdd` opens the add sheet.
enum DebugLaunch {
    static var inMemory: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalInMemory") }
    static var openAdd: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalOpenAdd") }
    /// `-JamaalOpenTask` opens the sample clinic task's detail; with `-JamaalOpenDefer` its defer sheet opens too.
    static var openTask: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalOpenTask") }
    static var openDefer: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalOpenDefer") }
    /// `-JamaalBegin` starts a session on the sample "Draft" task, 24 minutes in; `-JamaalOpenFocus` opens its screen.
    static var begin: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalBegin") }
    static var openFocus: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalOpenFocus") }
    /// `-JamaalPickUp` adds a session on the clinic task that the rollover closed this morning (42 minutes).
    static var pickUp: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalPickUp") }
    /// `-JamaalPlan N` opens Night Planning and moves on to step N (1 Review … 4 Load), to look at each screen.
    static var planStep: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-JamaalPlan"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }
    /// `-JamaalMorning` / `-JamaalEvening` pretend it is 09:00 / 21:00 for the morning card and the evening row. In
    /// the in-memory test mode they are otherwise off, so UI tests don't change with the time of day.
    static var morning: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalMorning") }
    static var evening: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalEvening") }
    /// `-JamaalTab habits` (or today, wellbeing, settings) opens that tab first.
    static var tab: AppTab? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-JamaalTab"), i + 1 < args.count else { return nil }
        return AppTab(rawValue: args[i + 1])
    }
    /// `-JamaalAnchorRules` adds real rules for the Anchors tab: a school run, bin night, plants (due now), a rule on
    /// a holiday break, one that needs attention (a newer version), and an archived one.
    static var anchorRules: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalAnchorRules") }
    /// `-JamaalNormalDayHistory` gives the last 14 days a record of 2h 45m of work each and a 4h normal day, so
    /// Settings offers its quiet "You usually do about 2h 45m" line.
    static var normalDayHistory: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalNormalDayHistory") }
    /// `-JamaalWellbeing gathering | steady | strained` gives Wellbeing a history: four active days; four weeks of
    /// mostly finished days with two heavy ones; or the same with the last three days over budget.
    static var wellbeingMode: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-JamaalWellbeing"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    /// `-JamaalOnboarding` shows first-launch onboarding (in-memory runs skip it otherwise, so tests don't change);
    /// `-JamaalOnboardingStep N` starts at the Nth screen (0 Meet … 8 Ready), to look at each one.
    static var onboarding: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalOnboarding") || onboardingStep != nil }
    static var onboardingStep: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-JamaalOnboardingStep"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }
    /// `-JamaalAccess subscribed | readOnly | trial:N` (N days left): the access state without the store, to look at each.
    enum AccessOverride: Equatable { case subscribed, readOnly, trial(daysLeft: Int) }
    static var access: AccessOverride? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-JamaalAccess"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "subscribed": return .subscribed
        case "readOnly": return .readOnly
        case let value where value.hasPrefix("trial:"): return Int(value.dropFirst(6)).map { .trial(daysLeft: $0) }
        default: return nil
        }
    }
    /// `-JamaalFailOpen`: the store won't open until it is reset (the recovery screen).
    static var failOpen: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalFailOpen") }
    /// In-memory runs start with onboarding already done (so tests see Today), once per launch; a reset then really starts over.
    nonisolated(unsafe) private static var autoCompleted = false
    @MainActor
    static func completeOnboardingForTests(in context: ModelContext, now: Date = .now) {
        guard inMemory, !onboarding, !autoCompleted else { return }
        guard let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first else { return }
        autoCompleted = true
        Onboarding.complete(settings, now: now)
    }
    static var sampleData: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalSampleData") }

    @MainActor
    static func insertSampleData(into context: ModelContext, now: Date = .now) {
        guard sampleData, ((try? context.fetchCount(FetchDescriptor<TaskItem>())) ?? 0) == 0 else { return }
        let categories = (try? context.fetch(FetchDescriptor<TaskCategory>())) ?? []
        func category(_ key: String) -> TaskCategory? { categories.first { $0.presetKey == key } }
        let today = TodayDay.boundary(in: context).logicalDate(at: now).storedDate
        let rows: [(String, Int, Importance, String, Int)] = [
            ("Draft the architecture review", 60, .high, "work", 0),
            ("Call the clinic back", 15, .medium, "personal", 2),
            ("Book Yusuf's swimming lessons", 30, .medium, "family", 0),
            ("Reply to Sam", 30, .low, "work", 0),
        ]
        insertSampleAnchors(into: context, now: now)
        insertSampleHabits(into: context, now: now)
        for (title, minutes, importance, key, deferrals) in rows {
            let task = TaskItem(title: title, dueDate: today, effortMinutes: minutes)
            task.importanceLevel = importance
            task.category = category(key)
            task.deferralCount = deferrals
            if title == "Call the clinic back" {
                task.notes = "- [ ] Ask about the **referral letter**\n- [x] Find the appointment number\n- [ ] Are *Thursday mornings* still open?"
            }
            context.insert(task)
        }
        if pickUp, let clinic = ((try? context.fetch(FetchDescriptor<TaskItem>())) ?? []).first(where: { $0.title == "Call the clinic back" }) {
            let boundary = TodayDay.boundary(in: context)
            let startOfToday = boundary.instant(of: boundary.logicalDate(at: now), atMinute: 0)
            let session = WorkSession()
            session.startedAt = startOfToday.addingTimeInterval(-42 * 60)
            session.endedAt = startOfToday
            session.day = boundary.logicalDate(at: startOfToday.addingTimeInterval(-60)).storedDate
            session.actualSeconds = 42 * 60
            session.outcome = SessionOutcome.autoClosed.rawValue
            context.insert(session)
            session.task = clinic
        }
        if begin, let draft = ((try? context.fetch(FetchDescriptor<TaskItem>())) ?? []).first(where: { $0.title == "Draft the architecture review" }) {
            draft.notes = "- [x] Outline the three options\n- [ ] Cost table for **option B**\n- [ ] Send to Priya for a read"
            if let session = try? FocusSessions.begin(task: draft, now: now.addingTimeInterval(-(24 * 60 + 10)), boundary: TodayDay.boundary(in: context), context: context) {
                _ = session
            }
        }
    }

    @MainActor
    static func insertWellbeingHistory(into context: ModelContext, now: Date = .now) {
        guard let mode = wellbeingMode, ((try? context.fetchCount(FetchDescriptor<DayPlan>())) ?? 0) == 0 else { return }
        let today = TodayDay.boundary(in: context).logicalDate(at: now)
        let span = mode == "gathering" ? 4 : 28
        for offset in 1...span {
            let day = today.addingDays(-offset)
            let plan = DayPlan()
            plan.date = day.storedDate
            plan.completionBasis = 4
            plan.completionRate = mode == "strained" && offset <= 3 ? 0.5 : 0.85
            plan.wasOverloaded = (mode == "strained" && offset <= 3) || (mode == "steady" && (offset == 4 || offset == 9))
            plan.completedEffortMinutes = 150
            context.insert(plan)
            let anchor = Anchor(title: "Asr")
            anchor.occurrenceDate = day.storedDate
            anchor.windowStart = TodayDay.boundary(in: context).instant(of: day, atMinute: 15 * 60)
            anchor.windowEnd = TodayDay.boundary(in: context).instant(of: day, atMinute: 17 * 60)
            anchor.slotKey = "asr"
            anchor.status = offset % 9 == 0 ? .missed : .attended
            context.insert(anchor)
        }
    }

    @MainActor
    static func insertNormalDayHistory(into context: ModelContext, now: Date = .now) {
        guard normalDayHistory, ((try? context.fetchCount(FetchDescriptor<DayPlan>())) ?? 0) == 0 else { return }
        let today = TodayDay.boundary(in: context).logicalDate(at: now)
        for offset in 1...14 {
            let plan = DayPlan()
            plan.date = today.addingDays(-offset).storedDate
            plan.completedEffortMinutes = 165
            context.insert(plan)
        }
        (try? context.fetch(FetchDescriptor<UserSettings>()))?.first?.mediumDayMinutes = 240
    }

    @MainActor
    static func insertSampleAnchorRules(into context: ModelContext, now: Date = .now) {
        guard anchorRules, ((try? context.fetchCount(FetchDescriptor<AnchorRule>())) ?? 0) == 0 else { return }
        let boundary = TodayDay.boundary(in: context)
        let today = boundary.logicalDate(at: now)
        let earlier = now.addingTimeInterval(-30 * 86_400)

        var school = AnchorRuleDraft.preset(.schoolRun, today: today)
        school.slots.append(AnchorSlotDraft(label: "Pick-up", startMinute: 15 * 60, windowMinutes: 30))
        _ = try? AnchorEditing.create(school, in: context, now: earlier)

        var bins = AnchorRuleDraft.preset(.binNight, today: today)
        bins.repeats = .days([2])
        _ = try? AnchorEditing.create(bins, in: context, now: earlier)

        var plants = AnchorRuleDraft.preset(.plantWatering, today: today)
        plants.markDueNow(today: today)
        _ = try? AnchorEditing.create(plants, in: context, now: earlier)

        var madrasa = AnchorRuleDraft.preset(.custom, today: today)
        madrasa.title = "Madrasa pick-up"; madrasa.repeats = .days([1, 2, 3, 4, 5])
        madrasa.slots = [AnchorSlotDraft(label: "Pick-up", startMinute: 15 * 60 + 30, windowMinutes: 30)]
        if let rule = try? AnchorEditing.create(madrasa, in: context, now: earlier) {
            try? AnchorEditing.addException(to: rule, from: today.addingDays(-1), to: today.addingDays(4), reason: .holiday)
        }

        var salah = PrayerRuleDraft(countryCode: "GB")
        salah.location = PrayerConfig.Location(mode: "manual", latitude: 52.64, longitude: -1.14, name: "Leicester")
        _ = try? PrayerEditing.create(salah, in: context, now: earlier)

        let newer = AnchorRule(title: "Swimming club"); newer.configData = #"{"version":99}"#; newer.createdAt = earlier
        context.insert(newer)

        let archived = AnchorRule(title: "Nursery drop-off"); archived.isArchived = true; archived.createdAt = earlier
        archived.configData = AnchorRuleDraft.preset(.schoolRun, today: today).slots.isEmpty ? "{}" : #"{"version":1,"recurrence":{"kind":"weekly","weekdays":[1]},"slots":[{"id":"a","label":"","start":"08:00","windowMinutes":30}],"exceptions":[]}"#
        context.insert(archived)
    }

    /// A config the generator can't read, so it leaves these hand-made instances alone instead of pruning them.
    private static let unreadable = "sample"

    /// A school run (opens an hour from now, so Attended is not yet possible) and a prayer-like group whose
    /// first window is open, so every row state shows.
    @MainActor
    private static func insertSampleAnchors(into context: ModelContext, now: Date) {
        func anchor(_ title: String, rule: AnchorRule?, start: TimeInterval, end: TimeInterval, minutes: Int? = nil) {
            let a = Anchor(title: title)
            a.occurrenceDate = TodayDay.boundary(in: context).logicalDate(at: now).storedDate
            a.windowStart = now.addingTimeInterval(start); a.windowEnd = now.addingTimeInterval(end)
            a.effortMinutes = minutes
            a.slotKey = title.lowercased()                      // distinct keys, or the dedup merges a rule's instances
            a.rule = rule
            context.insert(a)
        }
        let school = AnchorRule(title: "School run"); school.configData = Self.unreadable; context.insert(school)
        anchor("School run", rule: school, start: 3600, end: 5400, minutes: 30)
        let salah = AnchorRule(title: "Salah"); salah.configData = Self.unreadable; context.insert(salah)
        anchor("Dhuhr", rule: salah, start: -3600, end: 3000)
        anchor("Asr", rule: salah, start: 7200, end: 12600)
    }

    /// Water (counted, 3 of 8), Read (timed, 12 of 20 min), Late-night scrolling (avoid), Floss (binary), and a
    /// Morning group with two of its three habits already done.
    @MainActor
    private static func insertSampleHabits(into context: ModelContext, now: Date) {
        let boundary = TodayDay.boundary(in: context)
        let today = boundary.logicalDate(at: now)
        func habit(_ title: String, _ kind: HabitKind, target: Int, amount: Int = 0, group: HabitGroup? = nil) {
            let h = Habit(title: title)
            h.habitKind = kind
            h.createdAt = now.addingTimeInterval(-30 * 86_400)
            context.insert(h)
            let w = HabitTimeWindow(); w.target = target
            context.insert(w); w.habit = h
            h.group = group
            if amount > 0 {
                let e = HabitEntry(); e.date = today.storedDate; e.target = target; e.amount = amount
                if amount >= target { e.completedAt = now }
                context.insert(e); e.window = w
            }
        }
        let morning = HabitGroup(); morning.title = "Morning"; context.insert(morning)
        habit("Stretch", .binary, target: 1, amount: 1, group: morning)
        habit("Vitamins", .binary, target: 1, amount: 1, group: morning)
        habit("Journal", .binary, target: 1, group: morning)
        habit("Water", .counted, target: 8, amount: 3)
        habit("Read", .timed, target: 20, amount: 12)
        habit("Late-night scrolling", .avoid, target: 1)
        habit("Floss", .binary, target: 1)

        // A month of Water, so the density grid has something to show: most days reach eight, some stop at four.
        if let water = ((try? context.fetch(FetchDescriptor<Habit>())) ?? []).first(where: { $0.title == "Water" }), let window = water.windows?.first {
            for offset in 1...30 {
                let day = today.addingDays(-offset)
                let e = HabitEntry(); e.date = day.storedDate; e.target = 8
                e.amount = offset % 5 == 0 ? 4 : 8
                if e.amount >= 8 { e.completedAt = now.addingTimeInterval(-Double(offset) * 86_400) }
                context.insert(e); e.window = window
            }
        }

        // Paused and archived, for the Habits tab.
        habit("Reading before bed", .binary, target: 1)
        if let reading = ((try? context.fetch(FetchDescriptor<Habit>())) ?? []).first(where: { $0.title == "Reading before bed" }) {
            try? HabitPauses.pause(reading, from: today.addingDays(-1), until: today.addingDays(3), reason: .travel)
        }
        habit("Cold shower", .binary, target: 1)
        if let cold = ((try? context.fetch(FetchDescriptor<Habit>())) ?? []).first(where: { $0.title == "Cold shower" }) { cold.isArchived = true }
    }
}
#endif
