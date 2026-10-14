import Foundation
import Testing
@testable import JamaalCore

/// What the small Next Anchor widget says for each state (frame WG-01): the word in the eyebrow, the name, the
/// clock-time line and the bar. Pure, so it is tested here and the extension only draws it.
struct NextAnchorDisplayTests {

    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private var end: Date { start.addingTimeInterval(2 * 3600) }
    private func window(_ name: String, rule: String? = nil, phase: WidgetSnapshot.AnchorPhase, progress: Double = 0) -> WidgetSnapshot.AnchorWindow {
        .init(id: UUID(), name: name, ruleTitle: rule, phase: phase, start: start, end: end, progress: progress)
    }
    private func snapshot(_ anchors: [WidgetSnapshot.AnchorWindow]) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: start, day: "2026-10-15", isReadOnly: false, tasksLeft: 0, tasksDone: 0, tasks: [], moreTasks: 0,
            capacity: .init(plannedMinutes: 0, budgetMinutes: 180, level: "medium", state: .light), anchors: anchors,
            planningAt: start, planningDue: false, dayEndsAt: end)
    }
    private func time(_ date: Date) -> String { date == end ? "15:32" : "15:00" }

    // MARK: Which state

    @Test func theOpenAnchorLeads() {
        let open = window("Dhuhr", rule: "Salah", phase: .open, progress: 0.1)
        #expect(snapshot([open, window("Asr", rule: "Salah", phase: .upcoming)]).nextAnchorDisplay == .open(open))
    }

    @Test func aClosingWindowIsItsOwnState() {
        let closing = window("Asr", rule: "Salah", phase: .closingSoon, progress: 0.8)
        #expect(snapshot([closing]).nextAnchorDisplay == .closingSoon(closing))
    }

    @Test func anUpcomingAnchorIsNext() {
        let next = window("School run", phase: .upcoming)
        #expect(snapshot([next]).nextAnchorDisplay == .upcoming(next))
    }

    @Test func aClosedUnmarkedWindowShowsOnlyWhenNothingIsOpenOrComing() {
        let missed = window("Bin night", phase: .needsAttention)
        #expect(snapshot([missed]).nextAnchorDisplay == .needsAttention(missed))
        let next = window("School run", phase: .upcoming)
        #expect(snapshot([next, missed]).nextAnchorDisplay == .upcoming(next), "never leads")
    }

    @Test func noAnchorsLeftIsSaidPlainly() {
        #expect(snapshot([]).nextAnchorDisplay == .noneLeft)
    }

    // MARK: Words

    @Test func theEyebrowNamesTheRuleAndTheState() {
        #expect(NextAnchorCopy.eyebrow(.open(window("Dhuhr", rule: "Salah", phase: .open))) == "Salah · open")
        #expect(NextAnchorCopy.eyebrow(.closingSoon(window("Asr", rule: "Salah", phase: .closingSoon))) == "Salah · closing")
        #expect(NextAnchorCopy.eyebrow(.upcoming(window("School run", phase: .upcoming))) == "Next")
        #expect(NextAnchorCopy.eyebrow(.needsAttention(window("Bin night", phase: .needsAttention))) == "Not marked yet")
        #expect(NextAnchorCopy.eyebrow(.noneLeft) == "Anchors")
    }

    @Test func aOneOffHasNoRuleSoItsEyebrowIsJustTheState() {
        #expect(NextAnchorCopy.eyebrow(.open(window("Dentist", phase: .open))) == "Open")
        #expect(NextAnchorCopy.eyebrow(.closingSoon(window("Dentist", phase: .closingSoon))) == "Closing")
    }

    @Test func theTitleIsTheNameOrAGentleStatement() {
        #expect(NextAnchorCopy.title(.open(window("Dhuhr", phase: .open))) == "Dhuhr")
        #expect(NextAnchorCopy.title(.noneLeft) == "Nothing more today.")
    }

    @Test func theDetailIsAClockTimeNotACountdown() {
        #expect(NextAnchorCopy.detail(.open(window("Dhuhr", phase: .open)), time: time) == "until 15:32")
        #expect(NextAnchorCopy.detail(.closingSoon(window("Asr", phase: .closingSoon)), time: time) == "until 15:32")
        #expect(NextAnchorCopy.detail(.upcoming(window("School run", phase: .upcoming)), time: time) == "opens 15:00")
        #expect(NextAnchorCopy.detail(.needsAttention(window("Bin night", phase: .needsAttention)), time: time) == "Closed at 15:32")
        #expect(NextAnchorCopy.detail(.noneLeft, time: time) == nil)
    }

    // MARK: The bar

    @Test func theBarFillsWithTimePassedAndOnlyItsLengthChangesWhenClosing() {
        #expect(NextAnchorCopy.bar(.open(window("Dhuhr", phase: .open, progress: 0.1))) == .init(fill: 0.1, style: .accent))
        #expect(NextAnchorCopy.bar(.closingSoon(window("Asr", phase: .closingSoon, progress: 0.8))) == .init(fill: 0.8, style: .accent))
    }

    @Test func anUpcomingBarIsAnOutlineAndAMissedOneIsNeutralAndFull() {
        #expect(NextAnchorCopy.bar(.upcoming(window("School run", phase: .upcoming))) == .init(fill: 0, style: .outline))
        #expect(NextAnchorCopy.bar(.needsAttention(window("Bin night", phase: .needsAttention))) == .init(fill: 1, style: .neutral))
        #expect(NextAnchorCopy.bar(.noneLeft) == nil)
    }

    @Test func aProgressOutsideZeroToOneIsClamped() {
        #expect(NextAnchorCopy.bar(.open(window("Dhuhr", phase: .open, progress: 1.4)))?.fill == 1)
        #expect(NextAnchorCopy.bar(.open(window("Dhuhr", phase: .open, progress: -0.2)))?.fill == 0)
    }
}
