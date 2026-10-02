import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Deferral (docs/schema/task.md, "Deferral behaviour"): a task moved to a later day *after its due
/// day has arrived*. Rescheduling something due later is not a deferral. At most one deferral per
/// task per logical day, and a later choice that day refines the record instead of adding another.
@MainActor
struct TaskDeferralTests {

    private func defer_(_ w: TaskWorld, _ task: TaskItem, from day: Int = 15, to target: Int?, reason: DeferralReason = .unspecified,
                        nowDay: Int = 15) throws -> TaskDeferral.Outcome {
        try TaskDeferral.defer(task, from: w.d(day), to: target.map { w.d($0) }, reason: reason, now: w.at(nowDay, 21), boundary: w.boundary, context: w.context)
    }

    @Test func aTaskDueTodayDeferredIsARealDeferral() throws {
        let w = try TaskWorld()
        let t = w.task("Groceries", due: 15)
        let outcome = try defer_(w, t, to: 16, reason: .tooMuch)
        #expect(outcome.kind == .deferred)
        #expect(t.deferralCount == 1)
        #expect(t.dueDate == w.d(16).storedDate)
        let record = try #require(t.deferrals?.first)
        #expect(record.day == w.d(15).storedDate)
        #expect(record.deferredTo == w.d(16).storedDate)
        #expect(record.reasonKind == .tooMuch)
        #expect(record.deferredOn == w.at(15, 21))
    }

    @Test func anOverdueTaskDeferredIsAlsoARealDeferral() throws {
        let w = try TaskWorld()
        let t = w.task("Old", due: 12)
        #expect(try defer_(w, t, to: 16).kind == .deferred)
        #expect(t.deferralCount == 1)
    }

    @Test func movingATaskThatIsDueLaterIsReschedulingNotADeferral() throws {
        let w = try TaskWorld()
        let t = w.task("Thursday's", due: 18, importance: .medium)
        let pushed = try defer_(w, t, to: 22)
        #expect(pushed.kind == .rescheduled)
        #expect(t.deferralCount == 0)
        #expect(t.deferrals?.isEmpty ?? true)
        #expect(t.dueDate == w.d(22).storedDate)
        #expect(t.importanceLevel == .medium)                              // no easing
        let pulled = try defer_(w, t, to: 16)                               // pulled in earlier: also not a deferral
        #expect(pulled.kind == .rescheduled)
        #expect(t.deferralCount == 0)
    }

    @Test func aBacklogTaskGivenADateIsRescheduled() throws {
        let w = try TaskWorld()
        let t = w.task("Someday")
        #expect(try defer_(w, t, to: 20).kind == .rescheduled)
        #expect(t.dueDate == w.d(20).storedDate)
        #expect(t.deferralCount == 0)
    }

    @Test func theFirstTwoDeferralsAreInstantAndTheThirdNeedsAPicker() throws {
        let w = try TaskWorld()
        let t = w.task("Slow", due: 15)
        #expect(!TaskDeferral.requiresPicker(t))
        _ = try defer_(w, t, to: 16)
        #expect(!TaskDeferral.requiresPicker(t))
        _ = try defer_(w, t, from: 16, to: 17, nowDay: 16)
        #expect(t.deferralCount == 2)
        #expect(TaskDeferral.requiresPicker(t))                            // the next one is the third
    }

    @Test func theThirdDeferralEasesMediumOrHighToLowAndFlagsItStale() throws {
        let w = try TaskWorld()
        let t = w.task("Report", due: 15, importance: .high, deferrals: 2)
        let outcome = try defer_(w, t, to: 16)
        #expect(t.deferralCount == 3)
        #expect(t.importanceLevel == .low)
        #expect(outcome.easedImportance)
        #expect(outcome.isStale)
        #expect(!outcome.suggestsRemoval)
    }

    @Test func onceEasedToLowTheTaskMayBeParkedAsSomeday() throws {
        let w = try TaskWorld()
        let t = w.task("Report", due: 15, importance: .medium, deferrals: 2)
        _ = try defer_(w, t, to: nil)                                      // the 3rd deferral, to Someday
        #expect(t.importanceLevel == .low)
        #expect(t.dueDate == nil)
    }

    @Test func anImportantTaskCannotBeParkedAsSomedayBeforeItsThirdDeferral() throws {
        let w = try TaskWorld()
        let t = w.task("Report", due: 15, importance: .high, deferrals: 0)
        #expect(throws: TaskRuleError.dateRequired) { _ = try defer_(w, t, to: nil) }
        #expect(t.deferralCount == 0)                                      // nothing changed
        #expect(t.dueDate == w.d(15).storedDate)
    }

    @Test func aRepeatingTaskCannotBeParkedAsSomeday() throws {
        let w = try TaskWorld()
        let t = w.task("Weekly", due: 15, deferrals: 5); t.repeatMode = .weekly
        #expect(throws: TaskRuleError.dateRequired) { _ = try defer_(w, t, to: nil) }
    }

    @Test func theFifthDeferralSuggestsRemoval() throws {
        let w = try TaskWorld()
        let t = w.task("Never", due: 15, deferrals: 4)
        let outcome = try defer_(w, t, to: 16)
        #expect(t.deferralCount == 5)
        #expect(outcome.suggestsRemoval)
    }

    @Test func aRealDeferralMustGoToALaterDay() throws {
        let w = try TaskWorld()
        let t = w.task("Today", due: 15)
        #expect(throws: TaskRuleError.notALaterDay) { _ = try defer_(w, t, to: 15) }
        #expect(throws: TaskRuleError.notALaterDay) { _ = try defer_(w, t, to: 14) }
        #expect(t.deferralCount == 0)
    }

    // MARK: One per task per logical day

    @Test func aSecondChoiceTheSameDayRefinesTheRecordInsteadOfCountingTwice() throws {
        let w = try TaskWorld()
        let t = w.task("Groceries", due: 15)
        _ = try defer_(w, t, to: 16, reason: .unspecified)
        let again = try defer_(w, t, from: 15, to: 18, reason: .notReady)
        #expect(again.kind == .refined)
        #expect(t.deferralCount == 1)
        #expect(t.deferrals?.count == 1)
        #expect(t.deferrals?.first?.reasonKind == .notReady)
        #expect(t.deferrals?.first?.deferredTo == w.d(18).storedDate)
        #expect(t.dueDate == w.d(18).storedDate)
    }

    @Test func planningAfterMidnightRefinesTheRolloversRecordForTheDayBeingReviewed() throws {
        let w = try TaskWorld()
        w.context.insert(UserSettings())
        let t = w.task("Groceries", due: 15)
        // 00:30 on the 16th: the rollover has just auto-deferred it from the 15th.
        _ = try Rollover.catchUp(in: w.context, boundary: w.boundary, lastProcessed: w.d(14), now: w.at(16, 0))
        #expect(t.deferralCount == 1)
        #expect(t.dueDate == w.d(16).storedDate)
        // The user, planning for the review of the 15th, chooses Later (the 20th).
        let outcome = try defer_(w, t, from: 15, to: 20, reason: .tooMuch, nowDay: 16)
        #expect(outcome.kind == .refined)
        #expect(t.deferralCount == 1)                                      // never double-counted
        #expect(t.deferrals?.count == 1)
        #expect(t.deferrals?.first?.reasonKind == .tooMuch)
        #expect(t.dueDate == w.d(20).storedDate)
    }
}
