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
    }
}
#endif
