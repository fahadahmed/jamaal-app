import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Wellbeing, part 2 (docs/architecture/rules-engine.md, module 5): the four patterns, the one action
/// each writes, and delivery as an inline card (one a day, a seven-day cooldown after *Not now*,
/// never a notification). Today is Thu 15 Oct 2026; yesterday is Wed 14 Oct. UTC.
@MainActor
struct WellbeingPatternsTests {

    private func world() throws -> TaskWorld {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        return w
    }

    private func d(_ day: Int, month: Int = 10) -> CalendarDate { CalendarDate(year: 2026, month: month, day: day)! }

    @discardableResult
    private func plan(_ w: TaskWorld, _ day: CalendarDate, completion: Double = 1, basis: Int = 3, overloaded: Bool = false, effort: Int = 0) -> DayPlan {
        let p = DayPlan()
        p.date = day.storedDate; p.completionRate = completion; p.completionBasis = basis
        p.wasOverloaded = overloaded; p.completedEffortMinutes = effort
        w.context.insert(p)
        return p
    }

    /// Fourteen calm active days, 1–14 Oct: past the gathering state, with nothing to remark on.
    private func calm(_ w: TaskWorld) {
        for day in 1...14 { plan(w, d(day)) }
    }

    private func patterns(_ w: TaskWorld, today: Int = 15) throws -> [WellbeingPattern] {
        try Wellbeing.patterns(now: w.at(today, 9), boundary: w.boundary, context: w.context)
    }

    private func kinds(_ list: [WellbeingPattern]) -> [PatternKind] { list.map(\.kind) }

    private func overload(_ w: TaskWorld, _ days: [Int]) throws {
        for day in days {
            let p = try #require(try w.context.fetch(FetchDescriptor<DayPlan>()).first { $0.date == d(day).storedDate })
            p.wasOverloaded = true
        }
    }

    // MARK: Gathering

    @Test func nothingIsRemarkedOnWhileStillGatheringData() throws {
        let w = try world()
        for day in 10...14 { plan(w, d(day), overloaded: true) }              // five active days, all heavy
        #expect(try patterns(w).isEmpty)
    }

    @Test func aCalmFortnightHasNoPatternsAndIsSteady() throws {
        let w = try world()
        calm(w)
        let found = try patterns(w)
        #expect(found.isEmpty)
        #expect(!Wellbeing.isStrained(found))
    }

    // MARK: heavyRun

    @Test func threeOverloadedDaysInARowEndingYesterdayIsAHeavyRun() throws {
        let w = try world()
        calm(w)
        try overload(w, [12, 13, 14])
        let found = try patterns(w)
        #expect(kinds(found) == [.heavyRun])
        #expect(found.first?.subjectKey == "heavyRun")
        #expect(Wellbeing.isStrained(found))
    }

    @Test func aBrokenOrOldRunIsNotAHeavyRun() throws {
        let broken = try world(); calm(broken); try overload(broken, [11, 12, 14])             // 13 was fine
        #expect(!kinds(try patterns(broken)).contains(.heavyRun))
        let old = try world(); calm(old); try overload(old, [9, 10, 11])                        // ended days ago
        #expect(!kinds(try patterns(old)).contains(.heavyRun))
        let two = try world(); calm(two); try overload(two, [13, 14])
        #expect(!kinds(try patterns(two)).contains(.heavyRun))
    }

    @Test func aDayWithNoRecordBreaksTheRun() throws {
        let w = try world()
        for day in 1...14 where day != 13 { plan(w, d(day)) }
        try overload(w, [11, 12, 14])
        #expect(!kinds(try patterns(w)).contains(.heavyRun))
    }

    // MARK: habitNeglect

    private func habit(_ w: TaskWorld, _ title: String = "Read", days: String = "1,2,3,4,5,6,7", kind: HabitKind = .binary, perWeek: Int = 0, windows: Int = 1) -> Habit {
        let h = Habit(title: title); h.habitKind = kind; h.scheduledDays = days; h.targetPerWeek = perWeek; h.createdAt = w.at(1, 0)
        w.context.insert(h)
        for _ in 0..<windows { let win = HabitTimeWindow(); w.context.insert(win); win.habit = h }
        return h
    }

    private func done(_ w: TaskWorld, _ h: Habit, days: [Int]) {
        for day in days {
            for win in h.windows ?? [] {
                let e = HabitEntry(); e.date = w.d(day).storedDate; e.amount = 1; e.target = 1; w.context.insert(e); e.window = win
            }
        }
    }

    @Test func aHabitMissedOnItsLastThreeScheduledDaysIsNeglected() throws {
        let w = try world()
        calm(w)
        let read = habit(w)
        done(w, read, days: Array(1...10))                                    // then nothing on 11–14
        let found = try patterns(w)
        #expect(kinds(found) == [.habitNeglect])
        #expect(found.first?.habit?.id == read.id)
        #expect(found.first?.subjectKey == "habitNeglect:\(read.id.uuidString)")
    }

    @Test func oneDoneDayAmongTheLastThreeIsNotNeglect() throws {
        let w = try world()
        calm(w)
        let read = habit(w)
        done(w, read, days: [1, 2, 3, 13])
        #expect(try patterns(w).isEmpty)
    }

    @Test func onlyScheduledDaysCountTowardTheThree() throws {
        let w = try world()
        calm(w)
        let gym = habit(w, "Gym", days: "1,3,5")                              // Mon, Wed, Fri: the last three are Wed 14, Mon 12, Fri 9
        done(w, gym, days: [8])                                                // done on an unscheduled Thursday: irrelevant
        #expect(kinds(try patterns(w)) == [.habitNeglect])
        done(w, gym, days: [9])
        #expect(try patterns(w).isEmpty)
    }

    @Test func aHabitWithTwoWindowsIsNeglectedOnlyIfEveryWindowWasMissed() throws {
        let w = try world()
        calm(w)
        let meds = habit(w, "Meds", windows: 2)
        let first = try #require(meds.windows?.first)
        let e = HabitEntry(); e.date = w.d(13).storedDate; e.amount = 1; e.target = 1; w.context.insert(e); e.window = first
        #expect(try patterns(w).isEmpty)                                       // one window done on the 13th
    }

    @Test func pausedArchivedWeeklyTargetAndAvoidHabitsAreNeverNeglected() throws {
        let w = try world()
        calm(w)
        let paused = habit(w, "Paused"); paused.pauses = [HabitPause(from: w.d(9), to: nil, reason: .travel)]
        let archived = habit(w, "Archived"); archived.isArchived = true
        _ = habit(w, "Weekly", perWeek: 3)
        _ = habit(w, "No sugar", kind: .avoid)
        #expect(try patterns(w).isEmpty)
        _ = (paused, archived)
    }

    @Test func anAvoidHabitIsNeverNeglectedEvenWithSlipsPastItsAllowance() throws {
        let w = try world()
        calm(w)
        let sugar = habit(w, "No sugar", kind: .avoid)
        let win = try #require(sugar.windows?.first)
        win.target = 0                                                          // no slips allowed
        for day in 12...14 {
            let e = HabitEntry(); e.date = w.d(day).storedDate; e.amount = 2; e.target = 0; w.context.insert(e); e.window = win
        }
        #expect(try patterns(w).isEmpty)                                        // its days read missed, but avoid habits are out of this pattern
    }

    @Test func aHabitTooNewToHaveThreeScheduledDaysIsNotNeglected() throws {
        let w = try world()
        calm(w)
        let fresh = habit(w, "New"); fresh.createdAt = w.at(13, 0)               // only 13 and 14 so far
        #expect(try patterns(w).isEmpty)
    }

    // MARK: completionCollapse

    @Test func aSharpFallInCompletionAgainstTheFortnightBeforeIsACollapse() throws {
        let w = try world()
        for day in 1...11 { plan(w, d(day), completion: 0.9) }
        for day in 12...14 { plan(w, d(day), completion: 0.2) }
        #expect(kinds(try patterns(w)) == [.completionCollapse])
    }

    @Test func aDipThatIsNotLowEnoughOrHasTooLittleHistoryIsNotACollapse() throws {
        let notLow = try world()
        for day in 1...11 { plan(notLow, d(day), completion: 0.9) }
        for day in 12...14 { plan(notLow, d(day), completion: 0.42) }               // under half of 0.9, but not under 40%
        #expect(try patterns(notLow).isEmpty)

        let thin = try world()
        for day in 1...9 { plan(thin, d(day), completion: 0, basis: 0) }              // active, but nothing to finish: not counted
        for day in 10...11 { plan(thin, d(day), completion: 0.9) }
        for day in 12...14 { plan(thin, d(day), completion: 0.2) }
        #expect(try patterns(thin).isEmpty)                                           // only two earlier counted days
    }

    @Test func daysWithNothingToFinishNeverCountTowardTheRecentThree() throws {
        let w = try world()
        for day in 1...11 { plan(w, d(day), completion: 0.9) }
        plan(w, d(12), completion: 0.2); plan(w, d(13), completion: 0.2)
        plan(w, d(14), completion: 0, basis: 0)                                     // nothing to finish: skipped over
        #expect(try patterns(w).isEmpty)                                              // the third counted day is the 11th: 0.9
    }

    // MARK: weekendOverplan

    @Test func aWeekendOverloadedOnTwoOfTheLastThreeIsOverplanned() throws {
        let w = try world()
        calm(w)
        let saturdays = try w.context.fetch(FetchDescriptor<DayPlan>()).filter { $0.date == d(3).storedDate || $0.date == d(10).storedDate }
        for p in saturdays { p.wasOverloaded = true }
        let found = try patterns(w)
        #expect(kinds(found) == [.weekendOverplan])
        #expect(found.first?.weekday == 6)                                            // Saturday
        #expect(found.first?.subjectKey == "weekendOverplan:6")
    }

    @Test func theMostOverloadedWeekendDayIsTheOneToLighten() throws {
        let w = try world()
        calm(w)
        for p in try w.context.fetch(FetchDescriptor<DayPlan>()) where [d(4), d(11)].contains(CalendarDate(storedDate: p.date)) { p.wasOverloaded = true }   // two Sundays
        let found = try patterns(w)
        #expect(found.first?.weekday == 7)
    }

    @Test func aTieBetweenSaturdayAndSundayLightensSaturday() throws {
        let w = try world()
        calm(w)
        for p in try w.context.fetch(FetchDescriptor<DayPlan>()) where [d(10), d(4)].contains(CalendarDate(storedDate: p.date)) { p.wasOverloaded = true }   // Sat 10th, Sun 4th
        #expect(try patterns(w).first?.weekday == 6)
    }

    @Test func oneOverloadedWeekendIsNotAPattern() throws {
        let w = try world()
        calm(w)
        for p in try w.context.fetch(FetchDescriptor<DayPlan>()) where CalendarDate(storedDate: p.date) == d(10) { p.wasOverloaded = true }
        #expect(try patterns(w).isEmpty)
    }

    @Test func theWeekendThatIsStillGoingDoesNotCount() throws {
        let w = try world()
        for day in 4...17 { plan(w, d(day)) }
        for p in try w.context.fetch(FetchDescriptor<DayPlan>()) where [d(10), d(17)].contains(CalendarDate(storedDate: p.date)) { p.wasOverloaded = true }
        #expect(try patterns(w, today: 18).isEmpty)                                    // today is Sunday the 18th: the 17th–18th weekend isn't over; only the 10th counts
    }

    // MARK: Priority and strain

    @Test func patternsComeInPriorityOrderAndAnyOfThemMeansStrained() throws {
        let w = try world()
        for day in 1...11 { plan(w, d(day), completion: 0.9) }
        for day in 12...14 { plan(w, d(day), completion: 0.2, overloaded: true) }
        let read = habit(w)
        done(w, read, days: Array(1...10))
        let found = try patterns(w)
        #expect(kinds(found) == [.heavyRun, .completionCollapse, .habitNeglect])
        #expect(Wellbeing.isStrained(found))
    }
}
