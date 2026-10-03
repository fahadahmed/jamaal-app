//
//  DebugLaunch.swift
//  Jamaal
//

#if DEBUG
import Foundation
import SwiftData
import JamaalCore

/// Launch arguments for UI tests and previews, in debug builds only: `-JamaalInMemory` keeps the store out of
/// the app's real data, and `-JamaalSampleData` adds a few tasks due today.
enum DebugLaunch {
    static var inMemory: Bool { ProcessInfo.processInfo.arguments.contains("-JamaalInMemory") }
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
        for (title, minutes, importance, key, deferrals) in rows {
            let task = TaskItem(title: title, dueDate: today, effortMinutes: minutes)
            task.importanceLevel = importance
            task.category = category(key)
            task.deferralCount = deferrals
            context.insert(task)
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
}
#endif
