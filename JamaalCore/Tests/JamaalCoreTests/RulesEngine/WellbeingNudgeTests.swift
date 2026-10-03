import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Delivering wellbeing (docs/architecture/rules-engine.md, module 5): one inline card at a time, one a
/// day, a seven-day cooldown after *Not now*, a preference to turn it off, and the one change each
/// pattern writes. Never a notification. Today is Thu 15 Oct 2026, UTC.
@MainActor
struct WellbeingNudgeTests {

    private func world() throws -> TaskWorld {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        return w
    }

    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }

    private let heavy = WellbeingPattern(kind: .heavyRun, subjectKey: "heavyRun")
    private let collapse = WellbeingPattern(kind: .completionCollapse, subjectKey: "completionCollapse")
    private let weekend = WellbeingPattern(kind: .weekendOverplan, subjectKey: "weekendOverplan:6", weekday: 6)

    private func current(_ w: TaskWorld, _ patterns: [WellbeingPattern], enabled: Bool = true, now: Int = 15, hour: Int = 9) throws -> WellbeingNudge? {
        try Wellbeing.currentNudge(patterns: patterns, now: w.at(now, hour), boundary: w.boundary, nudgesEnabled: enabled, context: w.context)
    }

    private func logs(_ w: TaskWorld) throws -> [NudgeLog] {
        try w.context.fetch(FetchDescriptor<NudgeLog>()).sorted { $0.sentAt < $1.sentAt }
    }

    // MARK: Which card

    @Test func theFirstPatternInPriorityOrderIsTheCard() throws {
        let w = try world()
        #expect(try current(w, [heavy, collapse])?.pattern.kind == .heavyRun)
        #expect(try current(w, [collapse, weekend])?.pattern.kind == .completionCollapse)
        #expect(try current(w, []) == nil)
    }

    @Test func nothingIsShownWhenTheUserTurnedWellbeingNudgesOff() throws {
        let w = try world()
        #expect(try current(w, [heavy], enabled: false) == nil)
    }

    @Test func oneCardADaySoOnceOneWasShownTodayOnlyThatOneRemains() throws {
        let w = try world()
        let first = try #require(try current(w, [heavy, collapse]))
        try Wellbeing.markShown(first, now: w.at(15, 9), boundary: w.boundary, context: w.context)
        #expect(try current(w, [collapse], hour: 12) == nil)                            // a different pattern: not today
        #expect(try current(w, [heavy, collapse], hour: 12)?.pattern.kind == .heavyRun) // the same one stays through the day
        #expect(try current(w, [collapse], now: 16)?.pattern.kind == .completionCollapse)   // tomorrow is another day
    }

    @Test func markingShownTwiceTheSameDayLogsItOnce() throws {
        let w = try world()
        let nudge = try #require(try current(w, [heavy]))
        try Wellbeing.markShown(nudge, now: w.at(15, 9), boundary: w.boundary, context: w.context)
        try Wellbeing.markShown(nudge, now: w.at(15, 14), boundary: w.boundary, context: w.context)
        let all = try logs(w)
        #expect(all.count == 1)
        #expect(all.first?.nudgeKind == .wellbeing)
        #expect(all.first?.subjectKey == "heavyRun")
        #expect(all.first?.sentAt == w.at(15, 9))
        #expect(all.first?.dismissedAt == nil)
    }

    // MARK: Not now

    @Test func notNowHidesThatPatternForSevenDaysThenItMayReturn() throws {
        let w = try world()
        let nudge = try #require(try current(w, [heavy]))
        try Wellbeing.dismiss(nudge, now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(try current(w, [heavy], hour: 11) == nil)                                // gone for today
        #expect(try current(w, [heavy], now: 21) == nil)                                 // six days later: still resting
        #expect(try current(w, [heavy], now: 22, hour: 11)?.pattern.kind == .heavyRun)   // seven days on: eligible again
    }

    @Test func notNowOnOnePatternDoesNotHideAnother() throws {
        let w = try world()
        let nudge = try #require(try current(w, [heavy, collapse]))
        try Wellbeing.dismiss(nudge, now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(try current(w, [heavy, collapse], now: 16)?.pattern.kind == .completionCollapse)
    }

    @Test func dismissingAPatternNeverShownBeforeStillLogsIt() throws {
        let w = try world()
        let nudge = try #require(try current(w, [weekend]))
        try Wellbeing.dismiss(nudge, now: w.at(15, 10), boundary: w.boundary, context: w.context)
        let all = try logs(w)
        #expect(all.count == 1)
        #expect(all.first?.dismissedAt == w.at(15, 10))
    }

    @Test func eachHabitIsItsOwnSubjectSoDismissingOneLeavesTheOthers() throws {
        let w = try world()
        let a = Habit(title: "A"), b = Habit(title: "B")
        w.context.insert(a); w.context.insert(b)
        let pa = WellbeingPattern(kind: .habitNeglect, subjectKey: "habitNeglect:\(a.id.uuidString)", habit: a)
        let pb = WellbeingPattern(kind: .habitNeglect, subjectKey: "habitNeglect:\(b.id.uuidString)", habit: b)
        let first = try #require(try current(w, [pa, pb]))
        #expect(first.pattern.habit?.id == a.id)
        try Wellbeing.dismiss(first, now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(try current(w, [pa, pb], now: 16)?.pattern.habit?.id == b.id)
    }

    // MARK: The one change each writes

    @Test func aHeavyRunMakesTomorrowALowDay() throws {
        let w = try world()
        let outcome = try Wellbeing.apply(WellbeingNudge(pattern: heavy), now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(outcome == .capacityLowered(d(16)))
        let plan = try #require(try w.context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.date == d(16).storedDate)
        #expect(plan.capacityLevel == .low)
    }

    @Test func weekendOverplanLowersThatWeekdaysDefaultOnly() throws {
        let w = try world()
        let settings = try #require(try w.context.fetch(FetchDescriptor<UserSettings>()).first)
        settings.weekdayLevels = #"{"6":"medium","7":"medium","3":"high"}"#
        let outcome = try Wellbeing.apply(WellbeingNudge(pattern: weekend), now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(outcome == .weekdayLowered(6))
        #expect(settings.defaultLevel(forISOWeekday: 6) == .low)
        #expect(settings.defaultLevel(forISOWeekday: 7) == .medium)
        #expect(settings.defaultLevel(forISOWeekday: 3) == .high)
    }

    @Test func aCollapseOffersTheRecentAverageRoundedToFifteenMinutes() throws {
        let w = try world()
        for (day, effort) in [(10, 100), (11, 112), (12, 0)] {
            let p = DayPlan(); p.date = d(day).storedDate; p.completedEffortMinutes = effort; w.context.insert(p)
        }
        let outcome = try Wellbeing.apply(WellbeingNudge(pattern: collapse), now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(outcome == .normalDayChanged(105))                                       // mean of 100 and 112 is 106; the day with none doesn't count
        #expect(try w.context.fetch(FetchDescriptor<UserSettings>()).first?.mediumDayMinutes == 105)
    }

    @Test func theNormalDayStaysWithinTheSliderAndIsLeftAloneWithNoData() throws {
        let w = try world()
        let none = try Wellbeing.apply(WellbeingNudge(pattern: collapse), now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(none == .nothing)
        #expect(try w.context.fetch(FetchDescriptor<UserSettings>()).first?.mediumDayMinutes == 180)
        let tiny = DayPlan(); tiny.date = d(12).storedDate; tiny.completedEffortMinutes = 5; w.context.insert(tiny)
        _ = try Wellbeing.apply(WellbeingNudge(pattern: collapse), now: w.at(15, 11), boundary: w.boundary, context: w.context)
        #expect(try w.context.fetch(FetchDescriptor<UserSettings>()).first?.mediumDayMinutes == 30)   // clamped to the slider's lower end
    }

    @Test func neglectOpensTheHabitAndWritesNothing() throws {
        let w = try world()
        let habit = Habit(title: "Read"); w.context.insert(habit)
        let pattern = WellbeingPattern(kind: .habitNeglect, subjectKey: "habitNeglect:\(habit.id.uuidString)", habit: habit)
        let outcome = try Wellbeing.apply(WellbeingNudge(pattern: pattern), now: w.at(15, 10), boundary: w.boundary, context: w.context)
        guard case .openHabit(let opened) = outcome else { Issue.record("expected openHabit"); return }
        #expect(opened.id == habit.id)
        #expect(try w.context.fetchCount(FetchDescriptor<DayPlan>()) == 0)
        #expect(try w.context.fetch(FetchDescriptor<UserSettings>()).first?.mediumDayMinutes == 180)
    }

    @Test func acceptingACardRestsThatPatternJustLikeNotNow() throws {
        let w = try world()
        _ = try Wellbeing.apply(WellbeingNudge(pattern: heavy), now: w.at(15, 10), boundary: w.boundary, context: w.context)
        #expect(try current(w, [heavy], now: 17) == nil)
        #expect(try logs(w).first?.dismissedAt == w.at(15, 10))
    }

    // MARK: Default level helper

    @Test func settingAWeekdaysDefaultKeepsTheOthersAndSurvivesAnUnreadableMap() {
        let settings = UserSettings()
        settings.setDefaultLevel(.high, forISOWeekday: 2)
        #expect(settings.defaultLevel(forISOWeekday: 2) == .high)
        #expect(settings.defaultLevel(forISOWeekday: 6) == .low)                          // the weekend defaults are kept
        settings.weekdayLevels = "not json"
        settings.setDefaultLevel(.low, forISOWeekday: 1)
        #expect(settings.defaultLevel(forISOWeekday: 1) == .low)
    }
}
