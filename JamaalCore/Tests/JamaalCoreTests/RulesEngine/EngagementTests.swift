import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// "Engaged" (docs/schema/habit.md, G-40): a day is engaged if something was actually done in
/// the app. Opening it alone doesn't count. One definition serves avoid habits and the rollover.
@MainActor
struct EngagementTests {

    @Test func nothingDoneMeansNoEngagement() throws {
        let w = try HabitWorld()
        #expect(try Engagement.engagedDays(in: w.context, boundary: w.boundary).isEmpty)
    }

    @Test func eachKindOfActivityEngagesItsDay() throws {
        let w = try HabitWorld()
        let task = TaskItem(title: "Done"); task.isCompleted = true; task.completedAt = w.instant(2); w.context.insert(task)
        let (_, window) = w.habit("Read"); w.entry(window, day: 3, amount: 1)
        let (_, avoid) = w.habit("No sugar", kind: .avoid, target: 0); w.entry(avoid, day: 4, amount: 0, completed: true)   // Held today
        let anchor = Anchor(); anchor.status = .attended; anchor.resolvedAt = w.instant(5); w.context.insert(anchor)
        let session = WorkSession(); session.day = w.d(6).storedDate; w.context.insert(session)
        let review = NightPlanningSession(); review.forDate = w.d(8).storedDate; review.isComplete = true; w.context.insert(review)   // reviews day 7
        let engaged = try Engagement.engagedDays(in: w.context, boundary: w.boundary)
        #expect(engaged == Set([2, 3, 4, 5, 6, 7].map(w.d)))
    }

    @Test func thingsThatAreNotActivityDoNotCount() throws {
        let w = try HabitWorld()
        let (_, window) = w.habit("Read"); w.entry(window, day: 3, amount: 0)                                       // un-ticked
        let pending = Anchor(); pending.resolvedAt = w.instant(4); w.context.insert(pending)                        // still pending
        let open = NightPlanningSession(); open.forDate = w.d(6).storedDate; w.context.insert(open)                  // not closed or skipped
        #expect(try Engagement.engagedDays(in: w.context, boundary: w.boundary).isEmpty)
    }

    @Test func aSkippedPlanningSessionIsEngagementForTheDayItReviewed() throws {
        let w = try HabitWorld()
        let skipped = NightPlanningSession(); skipped.forDate = w.d(10).storedDate; skipped.skippedAt = w.instant(9, 21)
        w.context.insert(skipped)
        #expect(try Engagement.engagedDays(in: w.context, boundary: w.boundary) == [w.d(9)])
    }

    @Test func aLateRolloverAttributesAnEarlyMorningTaskToTheDayBefore() throws {
        let w = try HabitWorld()
        let late = DayBoundary(rolloverMinute: 180, timeZone: TimeZone(identifier: "UTC")!)
        let task = TaskItem(title: "Late"); task.isCompleted = true
        task.completedAt = late.instant(of: w.d(3), atMinute: 60)          // 01:00 on the 3rd is still the 2nd
        w.context.insert(task)
        #expect(try Engagement.engagedDays(in: w.context, boundary: late) == [w.d(2)])
    }
}
