import Foundation
import Testing
@testable import JamaalCore

/// What the Today widget says (frame WG-03): the headline and its mood, the capacity figures, how many tasks each size shows, the
/// Anchor line and the quiet notes. Pure, so it is tested here and the extension only draws it.
struct TodayWidgetDisplayTests {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private func line(_ title: String, minutes: Int? = 30) -> WidgetSnapshot.TaskLine {
        .init(id: UUID(), title: title, effortMinutes: minutes, categoryColorKey: nil)
    }
    private func anchor(_ name: String, phase: WidgetSnapshot.AnchorPhase, progress: Double = 0.2) -> WidgetSnapshot.AnchorWindow {
        .init(id: UUID(), name: name, ruleTitle: nil, phase: phase, start: start, end: start.addingTimeInterval(3600), progress: progress)
    }
    private func snapshot(
        left: Int = 4, done: Int = 0, planned: Int = 135, budget: Int = 180, state: LoadState = .balanced,
        anchors: [WidgetSnapshot.AnchorWindow] = [], planningDue: Bool = false, readOnly: Bool = false
    ) -> WidgetSnapshot {
        let tasks = (1...max(1, left)).prefix(5).map { line("Task \($0)", minutes: 15 * $0) }
        return WidgetSnapshot(
            generatedAt: start, day: "2026-10-15", isReadOnly: readOnly, tasksLeft: left, tasksDone: done,
            tasks: left == 0 ? [] : Array(tasks), moreTasks: max(0, left - 5),
            capacity: .init(plannedMinutes: planned, budgetMinutes: budget, level: "medium", state: state), anchors: anchors,
            planningAt: start, planningDue: planningDue, dayEndsAt: start.addingTimeInterval(7200))
    }
    private func display(_ s: WidgetSnapshot) -> TodayWidgetDisplay { s.todayWidgetDisplay }
    private func time(_ date: Date) -> String { date == start ? "15:00" : "16:00" }

    // MARK: Mood and headline

    @Test func aNormalDayIsFourThingsGentlyPaced() {
        let d = display(snapshot(left: 4))
        #expect(d.mood == .normal)
        #expect(d.eyebrow == "Today")
        #expect(d.headline == .init(first: "Four things,", second: "gently paced."))
    }

    @Test func oneThingAndManyThings() {
        #expect(display(snapshot(left: 1)).headline.first == "One thing,")
        #expect(display(snapshot(left: 10)).headline.first == "Ten things,")
        #expect(display(snapshot(left: 12)).headline.first == "12 things,", "digits past ten, as Today does")
    }

    @Test func fromThePlanningTimeItIsTheEvening() {
        let d = display(snapshot(left: 1, planningDue: true))
        #expect(d.mood == .evening)
        #expect(d.eyebrow == "This evening")
        #expect(d.headline == .init(first: "One thing left,", second: "then rest."))
        #expect(display(snapshot(left: 3, planningDue: true)).headline.first == "Three things left,")
    }

    @Test func aFinishedDayIsAllDoneAndTheRestIsYours() {
        let d = display(snapshot(left: 0, done: 4, planningDue: true))
        #expect(d.mood == .allDone)
        #expect(d.headline == .init(first: "All done.", second: "The rest is yours."))
        #expect(d.doneLine == "4 of 4 done")
        #expect(!d.showsCapacity, "the bar steps aside")
    }

    @Test func aBlankDaySaysSoCalmlyWithNoBarAndNoPrompt() {
        let d = display(snapshot(left: 0, done: 0))
        #expect(d.mood == .blank)
        #expect(d.headline == .init(first: "Nothing planned.", second: "An open day."))
        #expect(d.doneLine == nil)
        #expect(!d.showsCapacity)
    }

    // MARK: Capacity

    @Test func theCapacityFiguresMatchToday() {
        let d = display(snapshot(planned: 135, budget: 180, state: .balanced))
        #expect(d.capacityText == "2h 15m of 3h")
        #expect(d.stateWord == "BALANCED")
        #expect(d.barFill == 0.75)
        #expect(d.isOver == false)
        #expect(d.showsCapacity)
    }

    @Test func anOverfullDayTurnsTheBarTerracottaAndNeverPastFull() {
        let d = display(snapshot(planned: 300, budget: 180, state: .overloaded))
        #expect(d.stateWord == "OVER")
        #expect(d.isOver)
        #expect(d.barFill == 1)
        #expect(display(snapshot(planned: 190, budget: 180, state: .full)).stateWord == "FULL")
    }

    @Test func aMissingBudgetDoesNotDivideByZero() {
        #expect(display(snapshot(planned: 30, budget: 0)).barFill == 0)
    }

    // MARK: Tasks

    @Test func theMediumShowsTwoTasksAndHowManyMore() {
        let d = display(snapshot(left: 4))
        #expect(d.mediumTasks.map(\.title) == ["Task 1", "Task 2"])
        #expect(d.mediumMore == "and 2 more")
        #expect(display(snapshot(left: 2)).mediumMore == nil)
        #expect(display(snapshot(left: 3)).mediumMore == "and 1 more")
    }

    @Test func theLargeShowsFiveTasksAndHowManyMore() {
        let d = display(snapshot(left: 6))
        #expect(d.largeTasks.count == 5)
        #expect(d.largeMore == "and 1 more task")
        #expect(display(snapshot(left: 8)).largeMore == "and 3 more tasks")
        #expect(display(snapshot(left: 5)).largeMore == nil)
    }

    @Test func aTasksMinutesAreOneQuietWord() {
        #expect(TodayWidgetCopy.effort(60) == "60 min")
        #expect(TodayWidgetCopy.effort(15) == "15 min")
        #expect(TodayWidgetCopy.effort(nil) == nil)
        #expect(TodayWidgetCopy.effort(0) == nil)
    }

    // MARK: The Anchor line

    @Test func theAnchorLineSaysUntilOrFromAClockTime() {
        #expect(TodayWidgetCopy.anchorLine(.open(anchor("Dhuhr", phase: .open)), time: time) == "Dhuhr · until 16:00")
        #expect(TodayWidgetCopy.anchorLine(.closingSoon(anchor("Asr", phase: .closingSoon)), time: time) == "Asr · until 16:00")
        #expect(TodayWidgetCopy.anchorLine(.upcoming(anchor("Isha", phase: .upcoming)), time: time) == "Isha · from 15:00")
        #expect(TodayWidgetCopy.anchorLine(.needsAttention(anchor("Bin night", phase: .needsAttention)), time: time) == "Bin night · not marked yet")
        #expect(TodayWidgetCopy.anchorLine(.noneLeft, time: time) == nil)
    }

    @Test func theDisplayCarriesTheNextAnchorAndItsBar() {
        let open = anchor("Dhuhr", phase: .open, progress: 0.4)
        let d = display(snapshot(anchors: [open]))
        #expect(d.anchor == .open(open))
        #expect(d.anchorBar == .init(fill: 0.4, style: .accent))
        #expect(display(snapshot(anchors: [])).anchor == .noneLeft)
        #expect(display(snapshot(anchors: [])).anchorBar == nil)
    }

    // MARK: Quiet notes and the link

    @Test func thePlanTomorrowPillComesFromThePlanningTimeAndGoesWhenReadOnly() {
        #expect(!display(snapshot(planningDue: false)).showsPlanTomorrow)
        #expect(display(snapshot(planningDue: true)).showsPlanTomorrow)
        let locked = display(snapshot(planningDue: true, readOnly: true))
        #expect(!locked.showsPlanTomorrow)
        #expect(locked.viewOnly, "one quiet note, never an upgrade prompt")
        #expect(!display(snapshot(readOnly: false)).viewOnly)
    }
}
