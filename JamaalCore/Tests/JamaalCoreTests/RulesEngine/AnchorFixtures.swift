import Foundation
import SwiftData
@testable import JamaalCore

/// Shared builders for the Anchor tests. Times are UTC with a midnight rollover unless given.
@MainActor
struct AnchorWorld {
    let context: ModelContext
    let boundary: DayBoundary

    init(rolloverMinute: Int = 0) throws {
        context = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        boundary = DayBoundary(rolloverMinute: rolloverMinute, timeZone: TimeZone(identifier: "UTC")!)
    }

    /// October 2026: the 1st is a Thursday, so the 5th is a Monday.
    func d(_ day: Int, month: Int = 10) -> CalendarDate { CalendarDate(year: 2026, month: month, day: day)! }
    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }

    func slot(_ id: String, _ label: String, _ start: String, minutes: Int, allDay: Bool = false) -> AnchorSlot {
        AnchorSlot(id: id, label: label, start: start, windowMinutes: minutes, allDay: allDay)
    }

    func scheduled(
        _ recurrence: AnchorRecurrence, slots: [AnchorSlot], endDate: CalendarDate? = nil,
        reminder: AnchorReminder? = nil, exceptions: [AnchorException] = []
    ) -> ScheduledConfig {
        ScheduledConfig(version: 1, recurrence: recurrence, slots: slots, endDate: endDate, reminder: reminder, exceptions: exceptions)
    }

    @discardableResult
    func rule(
        _ title: String = "School run", _ config: ScheduledConfig, effort: Int? = 30,
        createdAt: Date? = nil, enabled: Bool = true, archived: Bool = false, source: AnchorSource = .schoolRun
    ) -> AnchorRule {
        let rule = AnchorRule(title: title)
        rule.source = source
        rule.configData = config.json
        rule.effortMinutes = effort
        rule.createdAt = createdAt ?? at(1, 0)
        rule.isEnabled = enabled
        rule.isArchived = archived
        context.insert(rule)
        return rule
    }

    func anchors() throws -> [Anchor] {
        try context.fetch(FetchDescriptor<Anchor>()).sorted { ($0.windowStart, $0.slotKey) < ($1.windowStart, $1.slotKey) }
    }

    @discardableResult
    func anchor(
        _ title: String = "Anchor", from start: Date, minutes: Int = 60, status: AttendanceStatus = .pending,
        rule: AnchorRule? = nil, day: Int? = nil, slot: String = ""
    ) -> Anchor {
        let a = Anchor(title: title)
        a.windowStart = start
        a.windowEnd = start.addingTimeInterval(Double(minutes) * 60)
        a.status = status
        a.slotKey = slot
        a.occurrenceDate = (day.map { d($0) } ?? boundary.logicalDate(at: start)).storedDate
        context.insert(a)
        a.rule = rule
        return a
    }
}
