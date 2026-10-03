import Foundation
import SwiftData
@testable import JamaalCore

/// Shared builders for the task tests. UTC with a midnight rollover. October 2026: the 1st is a
/// Thursday, so Mon 12, Thu 15, Sat 17, Sun 18, Mon 19.
@MainActor
struct TaskWorld {
    let context: ModelContext
    let boundary = DayBoundary(rolloverMinute: 0, timeZone: TimeZone(identifier: "UTC")!)

    init() throws { context = ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }

    func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    func at(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }

    @discardableResult
    func task(
        _ title: String, due: Int? = nil, importance: Importance = .low, deferrals: Int = 0,
        minutes: Int? = 30, created: Int = 1
    ) -> TaskItem {
        let t = TaskItem(title: title, dueDate: due.map { d($0).storedDate }, effortMinutes: minutes)
        t.importanceLevel = importance
        t.deferralCount = deferrals
        t.createdAt = at(created, 9)
        context.insert(t)
        return t
    }
}
