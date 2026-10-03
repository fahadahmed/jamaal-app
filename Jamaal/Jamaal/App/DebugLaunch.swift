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
        for (title, minutes, importance, key, deferrals) in rows {
            let task = TaskItem(title: title, dueDate: today, effortMinutes: minutes)
            task.importanceLevel = importance
            task.category = category(key)
            task.deferralCount = deferrals
            context.insert(task)
        }
    }
}
#endif
