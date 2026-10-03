import Foundation
import Testing
@testable import JamaalCore

/// Which tasks Today shows at each capacity level, and in what order (docs/journeys/today-list.md).
@MainActor
struct TodayTasksTests {

    private func list(_ w: TaskWorld, _ tasks: [TaskItem], level: CapacityLevel = .high, today: Int = 15) -> TodayTaskList {
        TodayTasks.list(tasks, today: w.d(today), level: level, boundary: w.boundary)
    }

    @Test func showsLiveTasksDueTodayOrOverdueInEngineOrder() throws {
        let w = try TaskWorld()
        let lowToday = w.task("low today", due: 15)
        let highToday = w.task("high today", due: 15, importance: .high)
        let overdue = w.task("overdue", due: 13)
        let tomorrow = w.task("tomorrow", due: 16)
        let done = w.task("done", due: 15); done.isCompleted = true; done.completedAt = w.at(15, 9)
        let dropped = w.task("dropped", due: 15); dropped.droppedAt = w.at(14)
        let r = list(w, [lowToday, tomorrow, dropped, done, overdue, highToday])
        #expect(r.shown.map(\.title) == ["high today", "overdue", "low today"])
        #expect(r.alsoToday.isEmpty)
        _ = (tomorrow, dropped, done)
    }

    @Test func completedTodayTasksAreListedSeparatelySoFinishingDoesNotRemoveThem() throws {
        let w = try TaskWorld()
        let doneToday = w.task("today", due: 15); doneToday.isCompleted = true; doneToday.completedAt = w.at(15, 9)
        let doneYesterday = w.task("yesterday", due: 14); doneYesterday.isCompleted = true; doneYesterday.completedAt = w.at(14, 9)
        let r = list(w, [doneToday, doneYesterday])
        #expect(r.completedToday.map(\.title) == ["today"])
    }

    @Test func undatedLowTasksFormTheBacklog() throws {
        let w = try TaskWorld()
        let backlog = w.task("someday")
        let r = list(w, [backlog])
        #expect(r.backlog.map(\.title) == ["someday"])
        #expect(r.shown.isEmpty)
    }

    @Test func atTheLowLevelOnlyUrgentAndImportantTasksAreShown() throws {
        let w = try TaskWorld()
        let important = w.task("important", due: 15, importance: .high)
        let plain = w.task("plain", due: 15)
        let r = list(w, [important, plain], level: .low)
        #expect(r.shown.map(\.title) == ["important"])
        #expect(r.alsoToday.map(\.title) == ["plain"])                      // nothing disappears: it is counted under "also today"
    }

    @Test(arguments: [CapacityLevel.medium, .high])
    func mediumAndHighShowEverythingDue(level: CapacityLevel) throws {
        let w = try TaskWorld()
        let r = list(w, [w.task("a", due: 15), w.task("b", due: 15, importance: .medium)], level: level)
        #expect(r.shown.count == 2)
        #expect(r.alsoToday.isEmpty)
    }

    @Test func anUnknownLevelBehavesAsMedium() throws {
        let w = try TaskWorld()
        let r = list(w, [w.task("a", due: 15)], level: .unknown)
        #expect(r.shown.count == 1)
    }
}
