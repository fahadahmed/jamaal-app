import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Module 7, free time (docs/architecture/rules-engine.md): the physical day. The working day
/// minus fixed Anchors, which cut it into blocks; flexible Anchors and habit minutes only
/// subtract. Times are UTC; the working day is 08:00–19:00 unless a test says otherwise.
@MainActor
struct FreeTimeTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private let day = CalendarDate(year: 2026, month: 10, day: 5)!      // a Monday

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        boundary.instant(of: day, atMinute: hour * 60 + minute)
    }

    private func fixed(_ title: String, _ hour: Int, _ minute: Int = 0, minutes: Int) -> FreeTime.Commitment {
        .init(title: title, start: at(hour, minute), windowEnd: at(hour, minute).addingTimeInterval(Double(minutes) * 60),
              minutes: minutes, isFixed: true)
    }

    private func compute(
        _ commitments: [FreeTime.Commitment] = [], habitMinutes: Int = 0, now: Date? = nil,
        dayStart: Int = 480, dayEnd: Int = 1140
    ) -> FreeTime.Result {
        FreeTime.compute(day: day, boundary: boundary, dayStartMinute: dayStart, dayEndMinute: dayEnd,
                         now: now, commitments: commitments, habitMinutes: habitMinutes)
    }

    // MARK: Blocks

    @Test func anEmptyWorkingDayIsOneBlock() {
        let r = compute()
        #expect(r.blocks.count == 1)
        #expect(r.freeMinutes == 660)
        #expect(r.longestBlockMinutes == 660)
        #expect(r.committedMinutes == 0)
        #expect(r.blocks.first?.before == nil)
        #expect(r.blocks.first?.after == nil)
    }

    @Test func aFixedCommitmentCutsTheDayAndNamesTheGapsAroundIt() throws {
        let r = compute([fixed("School run", 8, 15, minutes: 30)])
        #expect(r.blocks.map(\.minutes) == [15, 615])
        #expect(r.blocks[0].before == "School run")
        #expect(r.blocks[0].after == nil)
        #expect(r.blocks[1].after == "School run")
        #expect(r.blocks[1].before == nil)
        #expect(r.freeMinutes == 630)
        #expect(r.committedMinutes == 30)
        #expect(r.longestBlockMinutes == 615)
    }

    @Test func gapsUnderTwentyMinutesAreHiddenButStillCountAsFreeTime() {
        let r = compute([fixed("School run", 8, 15, minutes: 30)])
        #expect(r.blocks.count == 2)
        #expect(r.visibleBlocks.map(\.minutes) == [615])                  // the 15-minute gap isn't shown
        #expect(r.freeMinutes == 630)                                       // but it still counts
    }

    @Test func aDayThatBeginsOrEndsWithACommitmentHasNoGapOnThatSide() {
        let r = compute([fixed("Standup", 8, minutes: 30), fixed("Dinner prep", 18, 30, minutes: 30)])
        #expect(r.blocks.map(\.minutes) == [600])
        #expect(r.blocks[0].after == "Standup")
        #expect(r.blocks[0].before == "Dinner prep")
    }

    @Test func gapsBetweenTwoCommitmentsAreNamedByBoth() {
        let r = compute([fixed("School run", 8, 15, minutes: 30), fixed("Dentist", 15, minutes: 60)])
        #expect(r.blocks.map(\.minutes) == [15, 375, 180])
        #expect(r.blocks[1].after == "School run")
        #expect(r.blocks[1].before == "Dentist")
    }

    @Test func overlappingFixedCommitmentsMergeIntoOneBusyBlock() {
        let r = compute([fixed("A", 10, minutes: 60), fixed("B", 10, 30, minutes: 60)])
        #expect(r.blocks.map(\.minutes) == [120, 450])                     // busy 10:00–11:30
        #expect(r.committedMinutes == 90)
        #expect(r.blocks[0].before == "A")
        #expect(r.blocks[1].after == "B")                                   // named by the commitment that ends it
    }

    @Test func busyTimeOutsideTheWorkingDayDoesNotCountOrCut() {
        let r = compute([
            fixed("Isha", 20, 15, minutes: 10),                              // after the day's end
            fixed("Fajr", 5, minutes: 20),                                   // before it starts
        ])
        #expect(r.blocks.count == 1)
        #expect(r.freeMinutes == 660)
        #expect(r.committedMinutes == 0)
    }

    @Test func aCommitmentRunningPastTheDaysEndIsClippedToIt() {
        let r = compute([fixed("Late meeting", 18, 30, minutes: 60)])
        #expect(r.blocks.map(\.minutes) == [630])
        #expect(r.committedMinutes == 30)
    }

    @Test func aCommitmentWithNoDurationDoesNotCut() {
        let r = compute([fixed("Reminder", 12, minutes: 0)])
        #expect(r.blocks.count == 1)
        #expect(r.freeMinutes == 660)
    }

    // MARK: Flexible time subtracts without cutting

    @Test func flexibleCommitmentsAndHabitMinutesComeOffTheTotalButNotTheBlocks() {
        let flexible = FreeTime.Commitment(title: "Bin night", start: at(8), windowEnd: at(19), minutes: 15, isFixed: false)
        let r = compute([flexible], habitMinutes: 45)
        #expect(r.blocks.count == 1)
        #expect(r.blocks.first?.minutes == 660)
        #expect(r.freeMinutes == 660 - 15 - 45)
        #expect(r.committedMinutes == 60)
        #expect(r.longestBlockMinutes == 660)                               // position isn't fixed, so no cut
    }

    @Test func aFlexibleCommitmentOutsideTheWorkingDayDoesNotCount() {
        let outside = FreeTime.Commitment(title: "Late", start: at(20), windowEnd: at(22), minutes: 30, isFixed: false)
        #expect(compute([outside]).freeMinutes == 660)
    }

    @Test func freeTimeNeverGoesBelowZero() {
        let r = compute([fixed("All day", 8, minutes: 600)], habitMinutes: 300)
        #expect(r.freeMinutes == 0)
    }

    // MARK: Today starts at the later of now and the working-day start

    @Test func todayCountsOnlyWhatIsLeftOfTheDay() {
        let r = compute([fixed("Dentist", 15, minutes: 60)], now: at(14))
        #expect(r.blocks.map(\.minutes) == [60, 180])                       // 14:00–15:00, 16:00–19:00
        #expect(r.freeMinutes == 240)
        #expect(r.committedMinutes == 60)
    }

    @Test func aCommitmentAlreadyUnderwayEatsTheStartOfWhatIsLeft() {
        let r = compute([fixed("Meeting", 13, minutes: 90)], now: at(14))   // 13:00–14:30
        #expect(r.blocks.map(\.minutes) == [270])                           // 14:30–19:00
        #expect(r.committedMinutes == 30)                                   // only the part still ahead
    }

    @Test func beforeTheWorkingDayStartsTodayIsTheWholeDay() {
        #expect(compute(now: at(6)).freeMinutes == 660)
    }

    @Test func afterTheDaysEndNothingIsLeft() {
        let r = compute(now: at(19, 30))
        #expect(r.blocks.isEmpty)
        #expect(r.freeMinutes == 0)
        #expect(r.longestBlockMinutes == 0)
    }

    // MARK: From Anchors

    @Test func onlyPendingAnchorsCountAndPlacementDecidesFixedOrFlexible() throws {
        let context = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        let flexRule = AnchorRule(title: "Plants"); flexRule.placementKind = .flexible
        context.insert(flexRule)
        func anchor(_ title: String, status: AttendanceStatus = .pending, minutes: Int?, rule: AnchorRule? = nil, hour: Int = 12) -> Anchor {
            let a = Anchor(title: title)
            a.status = status
            a.effortMinutes = minutes
            a.windowStart = at(hour)
            a.windowEnd = at(hour + 1)
            context.insert(a)
            a.rule = rule
            return a
        }
        let pending = anchor("Dentist", minutes: 60, hour: 15)
        let skipped = anchor("Bin night", status: .skipped, minutes: 20)
        let attended = anchor("Asr", status: .attended, minutes: 10)
        let delegated = anchor("School run", status: .delegated, minutes: 30)
        let flexible = anchor("Water plants", minutes: 10, rule: flexRule)
        let commitments = FreeTime.commitments(from: [pending, skipped, attended, delegated, flexible])
        #expect(commitments.map(\.title) == ["Dentist", "Water plants"])
        #expect(commitments.map(\.isFixed) == [true, false])
        #expect(commitments.map(\.minutes) == [60, 10])
    }

    // MARK: Signals

    @Test func overflowIsPlannedMinutesBeyondFreeTime() {
        #expect(FreeTime.overflowMinutes(plannedMinutes: 250, freeMinutes: 180) == 70)
        #expect(FreeTime.overflowMinutes(plannedMinutes: 100, freeMinutes: 180) == 0)
    }

    @Test(arguments: [
        (600, CapacityLevel.high),     // budgets for a 180-minute day: low 120, medium 180, high 240
        (240, .high), (239, .medium), (180, .medium), (179, .low), (120, .low), (30, .low), (0, .low),
    ])
    func suggestedCapacityIsTheHighestLevelThatFitsAndNeverBelowLow(free: Int, expected: CapacityLevel) {
        #expect(FreeTime.suggestedCapacity(freeMinutes: free, mediumDayMinutes: 180) == expected)
    }

    @Test func aTaskLongerThanTheLongestBlockDoesNotFit() {
        let short = TaskItem(title: "Call", effortMinutes: 30)
        let review = TaskItem(title: "Review", effortMinutes: 90)
        let unsized = TaskItem(title: "Tidy")
        #expect(FreeTime.tasksThatDoNotFit([short, review, unsized], longestBlockMinutes: 60).map(\.title) == ["Review"])
        #expect(FreeTime.tasksThatDoNotFit([short, review, unsized], longestBlockMinutes: 90).isEmpty)
    }

    @Test func countsTasksWithNoDuration() {
        let sized = TaskItem(title: "A", effortMinutes: 30)
        let unsized = TaskItem(title: "B")
        let zero = TaskItem(title: "C", effortMinutes: 0)
        #expect(FreeTime.missingDurations([sized, unsized, zero]) == 1)     // 0 is an explicit duration
    }
}
