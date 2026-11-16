import Foundation
import Testing
@testable import JamaalCore

/// The hidden Eisenhower lens (docs/schema/task.md, "Derived, never stored"): urgency and
/// importance give a quadrant that drives ordering, capacity filtering and prompts. Never shown.
@MainActor
struct TaskPriorityTests {

    // Today is Thu 15 Oct.

    @Test(arguments: [
        (13, true), (15, true), (16, true),          // overdue, today, tomorrow
        (17, false), (30, false),                    // the day after tomorrow and later
    ])
    func aTaskIsUrgentWhenDueTomorrowOrEarlier(due: Int, urgent: Bool) throws {
        let w = try TaskWorld()
        #expect(TaskPriority.isUrgent(w.task("T", due: due), today: w.d(15)) == urgent)
    }

    @Test func aBacklogTaskIsNotUrgentUnlessItKeepsSlipping() throws {
        let w = try TaskWorld()
        #expect(!TaskPriority.isUrgent(w.task("Backlog"), today: w.d(15)))
        #expect(TaskPriority.isUrgent(w.task("Slipping", due: 30, deferrals: 3), today: w.d(15)))
        #expect(!TaskPriority.isUrgent(w.task("Twice", due: 30, deferrals: 2), today: w.d(15)))
    }

    @Test func importanceIsMediumOrHighAndAnUnknownLevelCountsAsLow() throws {
        let w = try TaskWorld()
        #expect(!TaskPriority.isImportant(w.task("L")))
        #expect(TaskPriority.isImportant(w.task("M", due: 15, importance: .medium)))
        #expect(TaskPriority.isImportant(w.task("H", due: 15, importance: .high)))
        let future = w.task("F"); future.importance = "critical"
        #expect(!TaskPriority.isImportant(future))
    }

    @Test func theFourQuadrants() throws {
        let w = try TaskWorld()
        #expect(TaskPriority.quadrant(w.task("a", due: 15, importance: .high), today: w.d(15)) == .doFirst)
        #expect(TaskPriority.quadrant(w.task("b", due: 20, importance: .medium), today: w.d(15)) == .schedule)
        #expect(TaskPriority.quadrant(w.task("c", due: 15), today: w.d(15)) == .fitIn)
        #expect(TaskPriority.quadrant(w.task("d"), today: w.d(15)) == .letGo)
    }

    @Test func staleFromTheThirdDeferralAndRemovalSuggestedFromTheFifth() throws {
        let w = try TaskWorld()
        #expect(!TaskPriority.isStale(w.task("a", deferrals: 2)))
        #expect(TaskPriority.isStale(w.task("b", deferrals: 3)))
        #expect(!TaskPriority.suggestsRemoval(w.task("c", deferrals: 4)))
        #expect(TaskPriority.suggestsRemoval(w.task("d", deferrals: 5)))
    }

    @Test func ordersByQuadrantThenDueDateThenCreation() throws {
        let w = try TaskWorld()
        let lowOverdue = w.task("low overdue", due: 13, created: 2)
        let lowToday = w.task("low today", due: 15, created: 1)
        let highToday = w.task("high today", due: 15, importance: .high, created: 3)
        let mediumTomorrow = w.task("medium tomorrow", due: 16, importance: .medium, created: 4)
        let mediumLater = w.task("medium later", due: 21, importance: .medium, created: 5)
        let backlog = w.task("backlog", created: 6)
        let ordered = TaskPriority.order([backlog, lowToday, mediumLater, lowOverdue, mediumTomorrow, highToday], today: w.d(15))
        #expect(ordered.map(\.title) == [
            "high today", "medium tomorrow",            // doFirst, by due date
            "medium later",                              // schedule
            "low overdue", "low today",                  // fitIn, overdue first
            "backlog",                                   // letGo
        ])
        _ = (lowOverdue, lowToday, highToday, mediumTomorrow, mediumLater, backlog)
    }

    @Test func sameQuadrantAndDateFallBackToTheOlderTaskThenAStableId() throws {
        let w = try TaskWorld()
        let newer = w.task("newer", due: 15, created: 5)
        let older = w.task("older", due: 15, created: 2)
        #expect(TaskPriority.order([newer, older], today: w.d(15)).map(\.title) == ["older", "newer"])
    }

    // MARK: Prompts

    @Test func askToPickPrioritiesWhenAPlanHasFiveTasksAndFewerThanTwoImportantOnes() throws {
        let w = try TaskWorld()
        let plain = (1...5).map { w.task("t\($0)", due: 16) }
        #expect(TaskPriority.shouldPickPriorities(plain))
        let one = plain + [w.task("h", due: 16, importance: .high)]
        #expect(TaskPriority.shouldPickPriorities(one))                 // still only one important
        let two = plain + [w.task("h1", due: 16, importance: .high), w.task("h2", due: 16, importance: .medium)]
        #expect(!TaskPriority.shouldPickPriorities(two))
        #expect(!TaskPriority.shouldPickPriorities(Array(plain.prefix(4))))   // fewer than five
    }

    @Test func askWhichMattersMostWhenSeveralTasksAreDoFirst() throws {
        let w = try TaskWorld()
        let one = [w.task("a", due: 15, importance: .high), w.task("b", due: 15)]
        #expect(!TaskPriority.hasMultipleDoFirst(one, today: w.d(15)))
        let two = one + [w.task("c", due: 16, importance: .medium)]
        #expect(TaskPriority.hasMultipleDoFirst(two, today: w.d(15)))
    }

    // MARK: Ties (#404)

    @Test func aHighTaskDueTomorrowDoesNotJumpAheadOfAMediumTaskDueToday() throws {
        let w = try TaskWorld()
        let medium = w.task("medium today", due: 15, importance: .medium, created: 5)
        let high = w.task("high tomorrow", due: 16, importance: .high, created: 1)          // both first-priority: important and due by tomorrow
        #expect(TaskPriority.quadrant(medium, today: w.d(15)) == TaskPriority.quadrant(high, today: w.d(15)))
        #expect(TaskPriority.order([high, medium], today: w.d(15)).map(\.title) == ["medium today", "high tomorrow"], "the day leads")
    }

    @Test func highComesBeforeMediumWhenBothAreDueTheSameDayEvenIfTheMediumIsOlder() throws {
        let w = try TaskWorld()
        let medium = w.task("medium today", due: 15, importance: .medium, created: 1)
        let high = w.task("high today", due: 15, importance: .high, created: 5)
        #expect(TaskPriority.order([medium, high], today: w.d(15)).map(\.title) == ["high today", "medium today"])
    }

    @Test func twoHighTasksDueTodayAreOrderedByWhichHasSlippedMoreThenTheShorterThenTheOlder() throws {
        let w = try TaskWorld()
        let fresh = w.task("fresh", due: 15, importance: .high, deferrals: 0, minutes: 30, created: 1)
        let slipped = w.task("slipped", due: 15, importance: .high, deferrals: 2, minutes: 90, created: 4)
        #expect(TaskPriority.order([fresh, slipped], today: w.d(15)).map(\.title) == ["slipped", "fresh"], "the one that keeps slipping first")

        let long = w.task("long", due: 15, importance: .high, minutes: 120, created: 2)
        let short = w.task("short", due: 15, importance: .high, minutes: 15, created: 3)
        #expect(TaskPriority.order([long, short], today: w.d(15)).map(\.title) == ["short", "long"], "then the quick one")

        let unknown = w.task("no estimate", due: 15, importance: .high, minutes: nil, created: 1)
        let known = w.task("estimated", due: 15, importance: .high, minutes: 120, created: 2)
        #expect(TaskPriority.order([unknown, known], today: w.d(15)).map(\.title) == ["estimated", "no estimate"], "an unknown estimate goes last")

        let older = w.task("older", due: 15, importance: .high, minutes: 30, created: 1)
        let newer = w.task("newer", due: 15, importance: .high, minutes: 30, created: 2)
        #expect(TaskPriority.order([newer, older], today: w.d(15)).map(\.title) == ["older", "newer"], "and finally the older one")
    }

    @Test func theDueDateStillDecidesBeforeSlippingAndEstimateWithinTheSameImportance() throws {
        let w = try TaskWorld()
        let overdue = w.task("overdue", due: 13, importance: .high, deferrals: 0, minutes: 120, created: 5)
        let today = w.task("today", due: 15, importance: .high, deferrals: 2, minutes: 15, created: 1)
        #expect(TaskPriority.order([today, overdue], today: w.d(15)).map(\.title) == ["overdue", "today"])
    }

    @Test func lowTasksKeepTheirOrderBecauseImportanceDoesNotSeparateThem() throws {
        let w = try TaskWorld()
        let later = w.task("later", due: 15, created: 1)
        let sooner = w.task("sooner", due: 14, created: 2)
        #expect(TaskPriority.order([later, sooner], today: w.d(15)).map(\.title) == ["sooner", "later"])
    }

    @Test func theOrderIsTheSameWhateverOrderTheTasksArriveIn() throws {
        let w = try TaskWorld()
        let tasks = [
            w.task("a", due: 15, importance: .high, deferrals: 1, minutes: 30, created: 1),
            w.task("b", due: 15, importance: .high, deferrals: 1, minutes: 30, created: 1),
            w.task("c", due: 16, importance: .medium, minutes: 15, created: 2),
            w.task("d", due: 15, importance: .low, minutes: 15, created: 3),
        ]
        let expected = TaskPriority.order(tasks, today: w.d(15)).map(\.id)
        for _ in 0..<5 { #expect(TaskPriority.order(tasks.shuffled(), today: w.d(15)).map(\.id) == expected) }
    }
}
