import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Night Planning orchestration, part 1 (docs/journeys/night-planning.md; rules engine module 4):
/// the session lifecycle, the Build and Load steps' read models, and Close. UTC, midnight rollover;
/// "tonight" is Thu 15 Oct 2026 and the plan is for Fri 16 Oct (a `medium` weekday). Sat 17 and
/// Sun 18 default to `low`.
@MainActor
struct NightPlanningTests {

    private func world() throws -> TaskWorld {
        let w = try TaskWorld()
        w.context.insert(UserSettings())                              // 180-minute normal day, 08:00–19:00
        return w
    }

    private func open(_ w: TaskWorld, for day: Int = 16, mode: PlanningMode = .evening, now: Date? = nil) throws -> NightPlanningSession {
        try NightPlanning.open(forDate: w.d(day), mode: mode, now: now ?? w.at(15, 21), context: w.context)
    }

    // MARK: Opening, resuming, re-opening

    @Test func aNewEveningSessionStartsAtReviewForTheTargetDate() throws {
        let w = try world()
        let s = try open(w)
        #expect(s.forDate == w.d(16).storedDate)
        #expect(s.step == .review)
        #expect(!s.isComplete)
        #expect(!s.isShortened)
        #expect(s.skippedAt == nil)
    }

    @Test func theMorningFlowIsAShortenedSessionForTodayStartingAtBuild() throws {
        let w = try world()
        let s = try open(w, for: 15, mode: .morning, now: w.at(15, 8))
        #expect(s.forDate == w.d(15).storedDate)
        #expect(s.step == .build)
        #expect(s.isShortened)
        #expect(NightPlanning.steps(for: s) == [.build, .load, .close])
        #expect(NightPlanning.steps(for: try open(w)) == [.review, .carry, .build, .load, .close])
    }

    @Test func openingADateThatHasASessionResumesItInsteadOfCreatingAnother() throws {
        let w = try world()
        let first = try open(w)
        first.step = .load
        let again = try open(w)
        #expect(again.id == first.id)
        #expect(again.step == .load)
        #expect(try w.context.fetchCount(FetchDescriptor<NightPlanningSession>()) == 1)
    }

    @Test func aClosedNightReopensAtBuildAndStaysConfirmedUntilItIsClosedAgain() throws {
        let w = try world()
        let s = try open(w)
        _ = try NightPlanning.close(s, boundary: w.boundary, now: w.at(15, 21, 30), context: w.context)
        #expect(s.isComplete)
        let reopened = try open(w)
        #expect(reopened.id == s.id)
        #expect(reopened.step == .build)
        #expect(reopened.isComplete)                                    // the plan stays confirmed while it is adjusted
    }

    @Test func aSkippedNightClearsTheSkipAndStartsAgain() throws {
        let w = try world()
        let s = try open(w)
        NightPlanning.skip(s, now: w.at(15, 21, 5))
        #expect(s.skippedAt != nil)
        let evening = try open(w)
        #expect(evening.id == s.id)
        #expect(evening.skippedAt == nil)
        #expect(evening.step == .review)

        let morning = try open(w, for: 15, mode: .morning, now: w.at(15, 8))
        NightPlanning.skip(morning, now: w.at(15, 8, 5))
        #expect(try open(w, for: 15, mode: .morning, now: w.at(15, 8, 10)).step == .build)       // a shortened flow restarts at its first step
    }

    // MARK: Moving between steps

    @Test func advancingWalksTheFiveStepsAndPassesThroughCarryWhenThereIsNothingToCarry() throws {
        let w = try world()
        let s = try open(w)
        #expect(NightPlanning.advance(s, carryHasWork: true) == .carry)
        #expect(NightPlanning.advance(s, carryHasWork: true) == .build)
        #expect(NightPlanning.advance(s, carryHasWork: true) == .load)
        #expect(NightPlanning.advance(s, carryHasWork: true) == .close)
        #expect(NightPlanning.advance(s, carryHasWork: true) == .close)                 // the end of the line

        let empty = try open(w, for: 17)
        #expect(NightPlanning.advance(empty, carryHasWork: false) == .build)           // carry skipped
    }

    @Test func backIsAvailableFromTheSecondStepAndSkipsAnEmptyCarry() throws {
        let w = try world()
        let s = try open(w)
        #expect(NightPlanning.back(s, carryHasWork: true) == .review)                  // already first: stays
        s.step = .build
        #expect(NightPlanning.back(s, carryHasWork: true) == .carry)
        s.step = .build
        #expect(NightPlanning.back(s, carryHasWork: false) == .review)                 // nothing to carry
        s.step = .close
        #expect(NightPlanning.back(s, carryHasWork: true) == .load)
    }

    @Test func aShortenedFlowOnlyMovesBuildLoadClose() throws {
        let w = try world()
        let s = try open(w, for: 15, mode: .morning, now: w.at(15, 8))
        #expect(NightPlanning.back(s, carryHasWork: true) == .build)                   // no Review or Carry to go back to
        #expect(NightPlanning.advance(s, carryHasWork: true) == .load)
        #expect(NightPlanning.advance(s, carryHasWork: true) == .close)
        #expect(NightPlanning.back(s, carryHasWork: true) == .load)
    }

    @Test func skippingWritesNoDayPlanAndLeavesTheSessionUnfinished() throws {
        let w = try world()
        let s = try open(w)
        NightPlanning.skip(s, now: w.at(15, 21, 10))
        #expect(s.skippedAt == w.at(15, 21, 10))
        #expect(!s.isComplete)
        #expect(try w.context.fetchCount(FetchDescriptor<DayPlan>()) == 0)
    }

    @Test func carryHasWorkWhenALiveTaskIsDueOnOrBeforeTheReviewedDay() throws {
        let w = try world()
        let overdue = w.task("Overdue", due: 14)
        let today = w.task("Today", due: 15)
        let later = w.task("Later", due: 16)
        let done = w.task("Done", due: 15); done.isCompleted = true
        let dropped = w.task("Dropped", due: 15); dropped.droppedAt = w.at(15)
        #expect(NightPlanning.carryHasWork([later], reviewDate: w.d(15)) == false)
        #expect(NightPlanning.carryHasWork([done, dropped], reviewDate: w.d(15)) == false)
        #expect(NightPlanning.carryHasWork([overdue], reviewDate: w.d(15)))
        #expect(NightPlanning.carryHasWork([today, later], reviewDate: w.d(15)))
    }

    // MARK: Build

    private func anchor(_ w: TaskWorld, _ title: String, day: Int = 16, hour: Int, minutes: Int, status: AttendanceStatus = .pending, flexible: Bool = false) -> Anchor {
        let a = Anchor(title: title)
        a.windowStart = w.at(day, hour)
        a.windowEnd = w.at(day, hour).addingTimeInterval(Double(minutes) * 60)
        a.occurrenceDate = w.d(day).storedDate
        a.effortMinutes = minutes
        a.status = status
        w.context.insert(a)
        if flexible { let rule = AnchorRule(title: title); rule.placementKind = .flexible; w.context.insert(rule); a.rule = rule }
        return a
    }

    @Test func buildOpensOnTomorrowsShapeWithNamedGaps() throws {
        let w = try world()
        _ = anchor(w, "School run", hour: 8, minutes: 30)
        _ = anchor(w, "Dentist", hour: 15, minutes: 60)
        _ = anchor(w, "Other day", day: 17, hour: 12, minutes: 60)                       // not tomorrow
        let build = try NightPlanning.build(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(build.freeTime.blocks.map(\.minutes) == [390, 180])                       // 08:30–15:00 and 16:00–19:00
        #expect(build.freeTime.blocks.map(\.after) == ["School run", "Dentist"])
        #expect(build.freeTime.blocks.map(\.before) == ["Dentist", nil])
        #expect(build.anchors.map(\.title) == ["School run", "Dentist"])
    }

    @Test func buildListsTomorrowsTasksInEngineOrderAndFlagsOnesThatDoNotFit() throws {
        let w = try world()
        _ = anchor(w, "Standup", hour: 8, minutes: 30)
        _ = anchor(w, "Meeting", hour: 10, minutes: 540)                                  // leaves 08:30–10:00 (90 min) as the longest block
        let long = w.task("Architecture review", due: 16, minutes: 120)
        let short = w.task("Call", due: 16, importance: .high, minutes: 30)
        _ = w.task("Next week", due: 22)
        let build = try NightPlanning.build(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(build.tasks.map(\.title) == ["Call", "Architecture review"])
        #expect(build.freeTime.longestBlockMinutes == 90)
        #expect(build.doesNotFit.map(\.id) == [long.id])                                  // a flag, never a block
        _ = short
    }

    @Test func buildShowsTomorrowsHabitsReadOnlyAndCountsTheirMinutes() throws {
        let w = try world()
        let habit = Habit(title: "Read"); habit.createdAt = w.at(1, 0); w.context.insert(habit)
        let window = HabitTimeWindow(); window.effortMinutes = 25; w.context.insert(window); window.habit = habit
        let paused = Habit(title: "Gym"); paused.createdAt = w.at(1, 0); w.context.insert(paused)
        paused.pauses = [HabitPause(from: w.d(14), to: nil, reason: .travel)]
        let pausedWindow = HabitTimeWindow(); pausedWindow.effortMinutes = 40; w.context.insert(pausedWindow); pausedWindow.habit = paused
        let build = try NightPlanning.build(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(build.habitWindows.map(\.habit.title) == ["Read"])                         // paused ones don't appear
        #expect(build.freeTime.freeMinutes == 660 - 25)
        #expect(build.freeTime.committedMinutes == 25)
    }

    @Test func buildSuggestsImportantNotYetUrgentTasksAndBacklogCandidates() throws {
        let w = try world()
        let schedule = w.task("Plan the quarter", due: 22, importance: .medium)
        let later = w.task("Much later", due: 30, importance: .high)
        let backlog = w.task("Someday thing")
        _ = w.task("Not important", due: 22)
        let build = try NightPlanning.build(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(build.scheduleSuggestions.map(\.title) == ["Plan the quarter", "Much later"])
        #expect(build.backlogCandidates.map(\.title) == ["Someday thing"])
        _ = (schedule, later, backlog)
    }

    @Test func buildRaisesTheTwoPrompts() throws {
        let w = try world()
        for i in 1...5 { _ = w.task("t\(i)", due: 16) }
        var build = try NightPlanning.build(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(build.shouldPickPriorities)
        #expect(!build.hasMultipleDoFirst)
        _ = w.task("h1", due: 16, importance: .high); _ = w.task("h2", due: 16, importance: .medium)
        build = try NightPlanning.build(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(!build.shouldPickPriorities)
        #expect(build.hasMultipleDoFirst)
    }

    @Test func buildCountsTasksWithNoDuration() throws {
        let w = try world()
        _ = w.task("No estimate", due: 16, minutes: nil)
        _ = w.task("Sized", due: 16, minutes: 30)
        let build = try NightPlanning.build(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(build.missingDurations == 1)
    }

    @Test func theMorningBuildOnlyCountsWhatIsLeftOfToday() throws {
        let w = try world()
        let build = try NightPlanning.build(forDate: w.d(15), boundary: w.boundary, now: w.at(15, 14), context: w.context)
        #expect(build.freeTime.freeMinutes == 5 * 60)                                      // 14:00–19:00
    }

    // MARK: Load

    @Test func theLevelDefaultsToTheWeekdaysAndIsWrittenTheMomentItIsChosen() throws {
        let w = try world()
        #expect(try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context).level == .medium)    // Friday
        #expect(try NightPlanning.loadCheck(forDate: w.d(17), boundary: w.boundary, now: w.at(15, 21), context: w.context).level == .low)       // Saturday
        #expect(try w.context.fetchCount(FetchDescriptor<DayPlan>()) == 0)                                                                     // reading writes nothing

        NightPlanning.setCapacity(.high, forDate: w.d(16), context: w.context)
        let plan = try #require(try w.context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.date == w.d(16).storedDate)
        #expect(plan.capacityLevel == .high)
        #expect(try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context).level == .high)    // survives leaving the app
        NightPlanning.setCapacity(.low, forDate: w.d(16), context: w.context)
        #expect(try w.context.fetchCount(FetchDescriptor<DayPlan>()) == 1)                                                                     // an upsert
    }

    @Test func theLoadCheckShowsBudgetUsedStateAndOverflow() throws {
        let w = try world()
        _ = anchor(w, "Meeting", hour: 8, minutes: 480)                                    // free time: 16:00–19:00 = 180 min
        _ = w.task("A", due: 16, minutes: 135)
        let check = try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(check.budgetMinutes == 180)
        #expect(check.plannedMinutes == 135)
        #expect(check.loadScore == 75)
        #expect(check.state == .balanced)
        #expect(check.overflowMinutes == 0)

        _ = w.task("B", due: 16, minutes: 90)
        let over = try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(over.plannedMinutes == 225)
        #expect(over.state == .overloaded)                                                 // 125%
        #expect(over.overflowMinutes == 45)                                                // 225 planned against 180 free
    }

    @Test func theEngineSuggestsALevelFromFreeTimeButTheUserDecides() throws {
        let w = try world()
        _ = anchor(w, "Meeting", hour: 8, minutes: 480)                                    // 180 minutes free
        let check = try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(check.suggestedLevel == .medium)                                           // medium's 180 fits; high's 240 doesn't
        #expect(check.level == .medium)
    }

    // MARK: The one reschedule suggestion

    @Test func anOverfullDayOffersToMoveTheLowestOrderedMovableTaskToTheNearestDayThatStaysUnderFull() throws {
        let w = try world()
        _ = w.task("Review", due: 16, importance: .high, minutes: 60)                      // doFirst: never moved
        _ = w.task("Slides", due: 16, minutes: 120, created: 2)
        let groceries = w.task("Groceries", due: 16, minutes: 90, created: 3)              // last in the order: the one to move
        _ = w.task("Saturday job", due: 17, minutes: 60)                                   // Saturday (low: 120 budget): 150/120 is over
        let check = try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        let suggestion = try #require(check.moveSuggestion)
        #expect(suggestion.task.id == groceries.id)
        #expect(suggestion.target == w.d(18))                                              // Sunday (low) stays at 75%
    }

    @Test func aDayThatWouldLandExactlyOnFullIsNotUnderFull() throws {
        let w = try world()
        _ = w.task("Review", due: 16, importance: .high, minutes: 60)
        _ = w.task("Slides", due: 16, minutes: 120, created: 2)
        let groceries = w.task("Groceries", due: 16, minutes: 60, created: 3)
        _ = w.task("Saturday job", due: 17, minutes: 60)                                  // 60 + 60 = 120 of Saturday's 120: exactly full
        let check = try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        #expect(check.moveSuggestion?.task.id == groceries.id)
        #expect(check.moveSuggestion?.target == w.d(18))                                  // Sunday, which stays at 50%
    }

    @Test func ifNoDayInTheNextWeekFitsTheUserIsAskedForADate() throws {
        let w = try world()
        _ = w.task("Review", due: 16, importance: .high, minutes: 60)
        _ = w.task("Huge", due: 16, minutes: 600, created: 2)
        let check = try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context)
        let suggestion = try #require(check.moveSuggestion)
        #expect(suggestion.task.title == "Huge")
        #expect(suggestion.target == nil)
    }

    @Test func aDayThatIsNotOverfullOffersNoMove() throws {
        let w = try world()
        _ = w.task("A", due: 16, minutes: 60)
        #expect(try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context).moveSuggestion == nil)
    }

    @Test func aDayOfOnlyDoFirstTasksHasNothingToSuggestMoving() throws {
        let w = try world()
        _ = w.task("A", due: 16, importance: .high, minutes: 200)
        _ = w.task("B", due: 16, importance: .medium, minutes: 200)
        #expect(try NightPlanning.loadCheck(forDate: w.d(16), boundary: w.boundary, now: w.at(15, 21), context: w.context).moveSuggestion == nil)
    }

    @Test func movingIsReschedulingNotADeferral() throws {
        let w = try world()
        let t = w.task("Groceries", due: 16, minutes: 90)
        try NightPlanning.move(t, to: w.d(18), reviewing: w.d(15), now: w.at(15, 21), boundary: w.boundary, context: w.context)
        #expect(t.dueDate == w.d(18).storedDate)
        #expect(t.deferralCount == 0)
        #expect(t.deferrals?.isEmpty ?? true)
    }

    // MARK: Close

    @Test func closingWritesTheSnapshotAndCompletesTheSession() throws {
        let w = try world()
        _ = anchor(w, "School run", hour: 8, minutes: 30)
        _ = w.task("Review", due: 16, importance: .high, minutes: 60)
        _ = w.task("Call", due: 16, minutes: 30)
        let s = try open(w)
        s.step = .close
        let summary = try NightPlanning.close(s, boundary: w.boundary, now: w.at(15, 21, 30), context: w.context)

        let plan = try #require(try w.context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.date == w.d(16).storedDate)
        #expect(plan.capacityLevel == .medium)                                              // the weekday default, since none was chosen
        #expect(plan.plannedTaskMinutes == 90)
        #expect(plan.loadScore == 50)
        #expect(!plan.wasOverloaded)
        #expect(plan.freeMinutes == 660 - 30)
        #expect(plan.committedMinutes == 30)
        #expect(plan.planningCompletedAt == w.at(15, 21, 30))
        #expect(s.isComplete)
        #expect(s.completedAt == w.at(15, 21, 30))
        #expect(s.step == .close)
        #expect(summary.taskCount == 2)
        #expect(summary.plannedMinutes == 90)
        #expect(summary.nightsPlanned == 1)
    }

    @Test func closingKeepsTheLevelTheUserChose() throws {
        let w = try world()
        NightPlanning.setCapacity(.low, forDate: w.d(16), context: w.context)
        _ = w.task("A", due: 16, minutes: 120)
        let s = try open(w)
        _ = try NightPlanning.close(s, boundary: w.boundary, now: w.at(15, 21, 30), context: w.context)
        let plan = try #require(try w.context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.capacityLevel == .low)
        #expect(plan.loadScore == 100)                                                       // 120 of low's 120
        #expect(try w.context.fetchCount(FetchDescriptor<DayPlan>()) == 1)
    }

    @Test func reClosingARopenedNightRewritesTheSameSnapshot() throws {
        let w = try world()
        let t = w.task("A", due: 16, minutes: 60)
        let s = try open(w)
        _ = try NightPlanning.close(s, boundary: w.boundary, now: w.at(15, 21, 30), context: w.context)
        _ = w.task("B", due: 16, minutes: 30)
        let reopened = try open(w)
        let summary = try NightPlanning.close(reopened, boundary: w.boundary, now: w.at(15, 22), context: w.context)
        #expect(try w.context.fetchCount(FetchDescriptor<DayPlan>()) == 1)
        #expect(try w.context.fetch(FetchDescriptor<DayPlan>()).first?.plannedTaskMinutes == 90)
        #expect(summary.nightsPlanned == 1)                                                  // the same night, not two
        _ = t
    }

    @Test func nightsPlannedCountsDistinctClosedNightsWithoutBeingAStreak() throws {
        let w = try world()
        for (day, hour) in [(16, 21), (17, 21), (19, 22)] {
            let s = try open(w, for: day, now: w.at(day - 1, hour))
            _ = try NightPlanning.close(s, boundary: w.boundary, now: w.at(day - 1, hour, 30), context: w.context)
        }
        let skipped = try open(w, for: 18, now: w.at(17, 21))
        NightPlanning.skip(skipped, now: w.at(17, 21, 5))
        let last = try open(w, for: 20, now: w.at(19, 21))
        let summary = try NightPlanning.close(last, boundary: w.boundary, now: w.at(19, 21, 30), context: w.context)
        #expect(summary.nightsPlanned == 4)                                                  // 16, 17, 19, 20; the skipped night isn't counted, and gaps don't matter
    }

    @Test func twoDevicesThatBothClosedTheSameNightCountOnce() throws {
        let w = try world()
        let a = try open(w)
        _ = try NightPlanning.close(a, boundary: w.boundary, now: w.at(15, 21, 30), context: w.context)
        let twin = NightPlanningSession()                                    // the other device's copy, not yet deduplicated
        twin.forDate = w.d(16).storedDate; twin.isComplete = true; twin.completedAt = w.at(15, 21, 31)
        w.context.insert(twin)
        let other = try open(w, for: 17, now: w.at(16, 21))
        let summary = try NightPlanning.close(other, boundary: w.boundary, now: w.at(16, 21, 30), context: w.context)
        #expect(summary.nightsPlanned == 2)                                  // nights 16 and 17, not three
    }

    @Test func aShortenedMorningSessionClosesTheSameWay() throws {
        let w = try world()
        _ = w.task("A", due: 15, minutes: 60)
        let s = try open(w, for: 15, mode: .morning, now: w.at(15, 8))
        _ = try NightPlanning.close(s, boundary: w.boundary, now: w.at(15, 8, 10), context: w.context)
        let plan = try #require(try w.context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.date == w.d(15).storedDate)
        #expect(plan.plannedTaskMinutes == 60)
        #expect(plan.planningCompletedAt == w.at(15, 8, 10))
        #expect(s.isComplete)
    }
}
