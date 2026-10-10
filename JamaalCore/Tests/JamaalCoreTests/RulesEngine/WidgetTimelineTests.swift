import Foundation
import Testing
@testable import JamaalCore

/// When a widget changes (docs/architecture/widgets-and-watch.md, "The timeline"): at the moments that alter what it
/// says, never per minute, and never more than a dozen entries.
struct WidgetTimelineTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }

    private func window(_ name: String, _ from: Date, _ to: Date, phase: WidgetSnapshot.AnchorPhase = .upcoming) -> WidgetSnapshot.AnchorWindow {
        .init(id: UUID(), name: name, ruleTitle: nil, phase: phase, start: from, end: to, progress: 0)
    }

    private func snapshot(_ anchors: [WidgetSnapshot.AnchorWindow], now: Date) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: now, day: "2026-10-15", isReadOnly: false, tasksLeft: 0, tasksDone: 0, tasks: [], moreTasks: 0,
            capacity: .init(plannedMinutes: 0, budgetMinutes: 180, level: "medium", state: .light), anchors: anchors,
            planningAt: at(15, 20), planningDue: false, dayEndsAt: at(16, 0))
    }

    @Test func nowIsAlwaysTheFirstEntry() {
        let now = at(15, 10)
        let plan = WidgetTimeline.plan(for: snapshot([], now: now), now: now)
        #expect(plan.entryDates.first == now)
    }

    @Test func theEntriesAreTheMomentsTheWidgetChanges() {
        let now = at(15, 12)
        let s = snapshot([window("Dhuhr", at(15, 13), at(15, 15))], now: now)
        let plan = WidgetTimeline.plan(for: s, now: now)
        #expect(plan.entryDates == [
            now,
            at(15, 13),          // the window opens
            at(15, 14, 30),      // its last quarter: closing soon
            at(15, 15),          // it closes
            at(15, 20),          // the planning time
            at(16, 0),           // the day ends
        ])
    }

    @Test func aShortWindowTurnsClosingSoonTenMinutesBeforeItCloses() {
        let now = at(15, 12)
        let s = snapshot([window("Quick", at(15, 13), at(15, 13, 20))], now: now)       // 20 min: a quarter is 5, so 10 apply
        #expect(WidgetTimeline.plan(for: s, now: now).entryDates.contains(at(15, 13, 10)))
    }

    @Test func momentsAlreadyPastAreLeftOut() {
        let now = at(15, 13, 45)
        let s = snapshot([window("Dhuhr", at(15, 13), at(15, 15), phase: .open)], now: now)
        let plan = WidgetTimeline.plan(for: s, now: now)
        #expect(!plan.entryDates.contains(at(15, 13)))
        #expect(plan.entryDates == [now, at(15, 14, 30), at(15, 15), at(15, 20), at(16, 0)])
    }

    @Test func anAnchorThatHasAlreadyClosedAddsNothing() {
        let now = at(15, 10)
        let s = snapshot([window("Bins", at(15, 8), at(15, 9), phase: .needsAttention)], now: now)
        #expect(WidgetTimeline.plan(for: s, now: now).entryDates == [now, at(15, 20), at(16, 0)])
    }

    @Test func momentsThatCoincideAreOneEntry() {
        let now = at(15, 10)
        let s = snapshot([window("Evening", at(15, 19), at(15, 20))], now: now)         // closes at the planning time
        let dates = WidgetTimeline.plan(for: s, now: now).entryDates
        #expect(dates.filter { $0 == at(15, 20) }.count == 1)
        #expect(dates == dates.sorted())
    }

    @Test func entriesAreCappedAndTheSystemIsAskedAgainAtTheLastOne() {
        let now = at(15, 6)
        let many = (7...19).map { h in window("A\(h)", at(15, h), at(15, h, 30)) }
        let plan = WidgetTimeline.plan(for: snapshot(many, now: now), now: now)
        #expect(plan.entryDates.count == WidgetTimeline.maxEntries)
        #expect(plan.entryDates == plan.entryDates.sorted())
        #expect(plan.reloadAfter == plan.entryDates.last)
    }

    @Test func withNothingElseTheDayEndAndThePlanningTimeAreTheOnlyLaterEntries() {
        let now = at(15, 21)                                                               // after the planning time
        let plan = WidgetTimeline.plan(for: snapshot([], now: now), now: now)
        #expect(plan.entryDates == [now, at(16, 0)])
        #expect(plan.reloadAfter == at(16, 0))
        #expect(plan.reloadAfter > now)
    }
}
