import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The notification planner (docs/architecture/rules-engine.md, module 6): a pure schedule over the
/// models and settings. Local notifications are capped at 64 pending, so one planner builds the
/// upcoming schedule in priority order. Now is Thu 15 Oct 2026, 10:00 UTC. Planning is at 20:00 and
/// the morning nudge at 08:00 (the defaults).
@MainActor
struct NotificationPlannerTests {

    private func world() throws -> AnchorWorld {
        let w = try AnchorWorld()
        w.context.insert(UserSettings())
        return w
    }

    private func plan(
        _ w: AnchorWorld, access: AccessState = .subscribed, trialStart: CalendarDate? = nil, permission: Bool = true,
        device: Bool = true, morning: Bool = false, hour: Int = 10, day: Int = 15
    ) throws -> [PlannedNotification] {
        try NotificationPlanner.plan(
            PlannerInputs(now: w.at(day, hour), boundary: w.boundary, access: access, trialStart: trialStart,
                          permissionGranted: permission, remindersOnThisDevice: device, morningNudgeEnabled: morning),
            context: w.context
        )
    }

    private func ids(_ list: [PlannedNotification]) -> [String] { list.map(\.id) }

    // MARK: Gates

    @Test func nothingIsScheduledWithoutPermissionOrWhenTheDeviceSwitchIsOff() throws {
        let w = try world()
        #expect(try !plan(w).isEmpty)
        #expect(try plan(w, permission: false).isEmpty)
        #expect(try plan(w, device: false).isEmpty)
        #expect(try plan(w, access: .trial(daysLeft: 3), trialStart: w.d(4), device: false).isEmpty)       // trial reminders obey the switch too
    }

    // MARK: The evening planning prompt

    @Test func thereIsOnePromptPerNightForFiveNightsAtThePlanningTime() throws {
        let w = try world()
        let prompts = try plan(w).filter { if case .planningPrompt = $0.kind { true } else { false } }
        #expect(prompts.count == 5)
        #expect(prompts.map(\.fireDate) == (15...19).map { w.at($0, 20) })
        guard case .planningPrompt(let forDate) = prompts[0].kind else { Issue.record("expected a prompt"); return }
        #expect(forDate == w.d(16))                                                    // tonight plans tomorrow
    }

    @Test func thePlanningTimeIsTheUsersAndTonightsPromptIsDroppedOncePassed() throws {
        let w = try world()
        let settings = try #require(try w.context.fetch(FetchDescriptor<UserSettings>()).first)
        settings.planningMinute = 21 * 60 + 30
        let evening = try plan(w, hour: 21, day: 15).filter { if case .planningPrompt = $0.kind { true } else { false } }
        #expect(evening.first?.fireDate == w.at(15, 21, 30))
        let late = try plan(w, hour: 22, day: 15).filter { if case .planningPrompt = $0.kind { true } else { false } }
        #expect(late.first?.fireDate == w.at(16, 21, 30))                              // 21:30 had passed
    }

    @Test func aNightThatIsClosedOrSkippedGetsNoPrompt() throws {
        let w = try world()
        let closed = NightPlanningSession(); closed.forDate = w.d(16).storedDate; closed.isComplete = true
        let skipped = NightPlanningSession(); skipped.forDate = w.d(17).storedDate; skipped.skippedAt = w.at(16, 21)
        let open = NightPlanningSession(); open.forDate = w.d(18).storedDate                // in progress: the prompt still stands
        for s in [closed, skipped, open] { w.context.insert(s) }
        let prompts = try plan(w).compactMap { n -> CalendarDate? in
            if case .planningPrompt(let date) = n.kind { date } else { nil }
        }
        #expect(prompts == [w.d(18), w.d(19), w.d(20)])
    }

    // MARK: The morning nudge

    @Test func theMorningNudgeIsOptional() throws {
        let w = try world()
        func mornings(_ list: [PlannedNotification]) -> [Date] { list.filter { $0.kind == .morningNudge }.map(\.fireDate) }
        #expect(try mornings(plan(w, morning: false)).isEmpty)
        #expect(try mornings(plan(w, morning: true)) == (16...19).map { w.at($0, 8) })     // today's 08:00 has passed; four more
    }

    // MARK: Anchor reminders

    private func scheduledRule(_ w: AnchorWorld, reminder: AnchorReminder?) -> AnchorRule {
        w.rule("School run", w.scheduled(.weekly(weekdays: [1, 2, 3, 4, 5]), slots: [w.slot("drop", "Drop-off", "08:15", minutes: 30)], reminder: reminder))
    }

    @Test func aStoredAnchorRemindsAtItsStartAndBeforeItEnds() throws {
        let w = try world()
        let a = w.anchor("Dentist", from: w.at(16, 15), minutes: 60)
        a.remindBeforeStartMinutes = 15
        a.remindBeforeEndMinutes = 10
        let list = try plan(w).filter { if case .anchorStart = $0.kind { true } else if case .anchorClosing = $0.kind { true } else { false } }
        #expect(list.map(\.fireDate) == [w.at(16, 14, 45), w.at(16, 15, 50)])
        #expect(list.map(\.kind) == [.anchorStart(title: "Dentist", leadMinutes: 15), .anchorClosing(title: "Dentist", minutesBefore: 10)])
    }

    @Test func zeroMeansAtTheStartAndNilMeansNone() throws {
        let w = try world()
        let at = w.anchor("At start", from: w.at(16, 9), minutes: 30); at.remindBeforeStartMinutes = 0
        _ = w.anchor("Quiet", from: w.at(16, 11), minutes: 30)
        let starts = try plan(w).filter { if case .anchorStart = $0.kind { true } else { false } }
        #expect(starts.map(\.fireDate) == [w.at(16, 9)])
    }

    @Test func decidedAnchorsAndRemindersAlreadyInThePastAreLeftOut() throws {
        let w = try world()
        let skipped = w.anchor("Skipped", from: w.at(16, 9), minutes: 30, status: .skipped); skipped.remindBeforeStartMinutes = 0
        let attended = w.anchor("Attended", from: w.at(16, 10), minutes: 30, status: .attended); attended.remindBeforeStartMinutes = 0
        let past = w.anchor("Earlier today", from: w.at(15, 8), minutes: 30); past.remindBeforeStartMinutes = 0               // 08:00 has gone
        let open = w.anchor("Open now", from: w.at(15, 9), minutes: 120); open.remindBeforeEndMinutes = 15                      // its closing reminder is still ahead
        let list = try plan(w).filter { if case .anchorStart = $0.kind { true } else if case .anchorClosing = $0.kind { true } else { false } }
        #expect(list.map(\.fireDate) == [w.at(15, 10, 45)])
        #expect(list.first?.kind == .anchorClosing(title: "Open now", minutesBefore: 15))
    }

    @Test func aRuleRemindsOverFiveDaysEvenBeyondTheStoredTwo() throws {
        let w = try world()
        _ = scheduledRule(w, reminder: AnchorReminder(atStart: true, beforeEndMinutes: nil))
        let starts = try plan(w).filter { if case .anchorStart = $0.kind { true } else { false } }
        // Thu 15 (08:15 has passed), Fri 16, then the weekend has no school run, Mon 19.
        #expect(starts.map(\.fireDate) == [w.at(16, 8, 15), w.at(19, 8, 15)])
    }

    @Test func aStoredInstanceIsNotRemindedTwiceAndItsDecisionIsRespected() throws {
        let w = try world()
        let rule = scheduledRule(w, reminder: AnchorReminder(atStart: true, beforeEndMinutes: nil))
        _ = try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: w.at(15, 7))                      // stores Thu and Fri
        let friday = try #require(try w.context.fetch(FetchDescriptor<Anchor>()).first { $0.occurrenceDate == w.d(16).storedDate })
        friday.status = .skipped
        let starts = try plan(w).filter { if case .anchorStart = $0.kind { true } else { false } }
        #expect(starts.map(\.fireDate) == [w.at(19, 8, 15)])                                                       // Friday skipped; no duplicate for the stored days
        _ = rule
    }

    @Test func aRuleWithRemindersOffMakesNoneAndADisabledRuleMakesNone() throws {
        let w = try world()
        _ = scheduledRule(w, reminder: nil)
        let off = scheduledRule(w, reminder: AnchorReminder(atStart: true, beforeEndMinutes: nil)); off.isEnabled = false
        #expect(try plan(w).filter { if case .anchorStart = $0.kind { true } else { false } }.isEmpty)
    }

    @Test func aPrayerRuleRemindsAtEachStartByDefault() throws {
        let w = try world()
        let config = PrayerConfig(method: "northAmerica", location: PrayerConfig.Location(mode: "manual", latitude: 35.775, longitude: -78.6336, name: "Raleigh"))
        let rule = AnchorRule(title: "Salah"); rule.source = .prayerWindow; rule.configData = config.json; rule.createdAt = w.at(1, 0); w.context.insert(rule)
        let starts = try plan(w).filter { if case .anchorStart = $0.kind { true } else { false } }
        #expect(starts.count > 15)                                                                                  // five a day over five days, minus what has passed
        #expect(starts.allSatisfy { if case .anchorStart(_, let lead) = $0.kind { lead == 0 } else { false } })
        #expect(Set(starts.compactMap { n -> String? in if case .anchorStart(let t, _) = n.kind { t } else { nil } }).isSuperset(of: ["Salah · Fajr", "Salah · Dhuhr", "Salah · Asr", "Salah · Maghrib", "Salah · Isha"]))   // "rule · slot", since they differ
    }

    // MARK: Habit reminders

    private func habit(_ w: AnchorWorld, _ title: String = "Read", reminder: Int? = 21 * 60, days: String = "1,2,3,4,5,6,7", perWeek: Int = 0) -> (Habit, HabitTimeWindow) {
        let h = Habit(title: title); h.scheduledDays = days; h.targetPerWeek = perWeek; h.createdAt = w.at(1, 0); w.context.insert(h)
        let win = HabitTimeWindow(); win.reminderMinute = reminder; w.context.insert(win); win.habit = h
        return (h, win)
    }

    @Test func aDueHabitRemindsTodayAndTomorrowAtItsTime() throws {
        let w = try world()
        _ = habit(w)
        let reminders = try plan(w).filter { if case .habitReminder = $0.kind { true } else { false } }
        #expect(reminders.map(\.fireDate) == [w.at(15, 21), w.at(16, 21)])
        #expect(reminders.first?.kind == .habitReminder(title: "Read"))
    }

    @Test func aHabitAlreadyDonePausedArchivedOrWithoutAReminderMakesNone() throws {
        let w = try world()
        let (_, doneWin) = habit(w, "Done")
        let e = HabitEntry(); e.date = w.d(15).storedDate; e.amount = 1; e.target = 1; w.context.insert(e); e.window = doneWin
        let (paused, _) = habit(w, "Paused"); paused.pauses = [HabitPause(from: w.d(14), to: nil, reason: .illness)]
        let (archived, _) = habit(w, "Archived"); archived.isArchived = true
        _ = habit(w, "No reminder", reminder: nil)
        let titles = try plan(w).compactMap { n -> String? in if case .habitReminder(let t) = n.kind { t } else { nil } }
        #expect(titles == ["Done"])                                                           // only tomorrow's: done today, but due again tomorrow
        _ = (paused, archived)
    }

    @Test func aWeeklyTargetHabitStopsRemindingOnceTheWeeksTargetIsMet() throws {
        let w = try world()
        let (_, win) = habit(w, "Run", perWeek: 1)
        let e = HabitEntry(); e.date = w.d(13).storedDate; e.amount = 1; e.target = 1; w.context.insert(e); e.window = win     // Tue 13: the week's one
        let reminders = try plan(w).filter { if case .habitReminder = $0.kind { true } else { false } }
        #expect(reminders.isEmpty)                                                            // met for the Monday-first week 12–18
    }

    // MARK: Trial reminders and the read-only gate

    @Test func trialEndRemindersAreAtNineOnDaysTwelveFourteenAndFifteen() throws {
        let w = try world()
        let list = try plan(w, access: .trial(daysLeft: 5), trialStart: w.d(4)).filter { if case .trialEnding = $0.kind { true } else { false } }
        // A trial that began on the 4th has its days 12, 14 and 15 on the 15th, 17th and 18th; 09:00 on the 15th has passed.
        #expect(list.map(\.fireDate) == [w.at(17, 9), w.at(18, 9)])
        #expect(list.map(\.kind) == [.trialEnding(day: 14), .trialEnding(day: 15)])
    }

    @Test func subscribingCancelsTheTrialReminders() throws {
        let w = try world()
        let list = try plan(w, access: .subscribed, trialStart: w.d(4))
        #expect(!list.contains { if case .trialEnding = $0.kind { true } else { false } })
    }

    @Test func readOnlyStopsEverythingExceptTheTrialEndReminders() throws {
        let w = try world()
        let dentist = w.anchor("Dentist", from: w.at(16, 15), minutes: 60); dentist.remindBeforeStartMinutes = 0
        _ = habit(w)
        let list = try plan(w, access: .readOnly, trialStart: w.d(2), morning: true, day: 15)                      // day 14: day 15's reminder is tomorrow
        #expect(list.allSatisfy { if case .trialEnding = $0.kind { true } else { false } })
        #expect(list.map(\.kind) == [.trialEnding(day: 15)])
        let none = try plan(w, access: .readOnly, trialStart: w.d(2), day: 20)                                      // a week on: nothing at all
        #expect(none.isEmpty)
    }

    // MARK: Budget and order

    @Test func theScheduleIsCappedAtSixtyAndKeepsTheHigherPrioritiesFirst() throws {
        let w = try world()
        for i in 0..<30 {                                                                       // 90 habit reminders over two days, far more than the budget allows
            _ = habit(w, "Habit \(i)", reminder: 11 * 60 + i)
        }
        let dentist = w.anchor("Dentist", from: w.at(16, 15), minutes: 60); dentist.remindBeforeStartMinutes = 0
        let list = try plan(w, access: .trial(daysLeft: 5), trialStart: w.d(4), morning: true)
        #expect(list.count == 60)
        #expect(list.contains { if case .planningPrompt = $0.kind { true } else { false } })     // the prompts, the nudge and the Anchor stay
        #expect(list.contains { if case .anchorStart = $0.kind { true } else { false } })
        #expect(list.filter { if case .morningNudge = $0.kind { true } else { false } }.count == 4)
        #expect(list.map(\.fireDate) == list.map(\.fireDate).sorted())                          // handed over in time order
        #expect(Set(ids(list)).count == list.count)                                              // every id unique
    }

    @Test func idsAreStableSoTheAppCanDiffAgainstWhatIsPending() throws {
        let w = try world()
        _ = habit(w)
        let dentist = w.anchor("Dentist", from: w.at(16, 15), minutes: 60); dentist.remindBeforeStartMinutes = 0
        let first = try plan(w)
        let second = try plan(w)
        #expect(ids(first) == ids(second))
        #expect(first.map(\.fireDate) == second.map(\.fireDate))
    }
}
