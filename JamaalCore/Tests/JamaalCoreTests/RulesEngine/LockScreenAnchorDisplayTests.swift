import Foundation
import Testing
@testable import JamaalCore

/// What the Next Anchor Lock Screen widgets say (frame WG-02): inline, circular and rectangular, by state. Plain facts, never a
/// countdown except "closes in 20 min" on the rectangular one, and no red.
struct LockScreenAnchorDisplayTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }
    private func time(_ date: Date) -> String {
        let m = Int((date.timeIntervalSince(now) / 60).rounded())
        return "t\(m >= 0 ? "+" : "")\(m)"
    }
    private func window(_ name: String, _ phase: WidgetSnapshot.AnchorPhase, from: Double, to: Double, progress: Double = 0.3) -> WidgetSnapshot.AnchorWindow {
        .init(id: UUID(), name: name, ruleTitle: nil, phase: phase, start: at(from), end: at(to), progress: progress)
    }
    private func lock(_ anchors: [WidgetSnapshot.AnchorWindow], tomorrow: WidgetSnapshot.AnchorWindow? = nil) -> LockScreenAnchorDisplay {
        WidgetSnapshot(
            generatedAt: now, day: "2026-10-15", isReadOnly: false, tasksLeft: 0, tasksDone: 0, tasks: [], moreTasks: 0,
            capacity: .init(plannedMinutes: 0, budgetMinutes: 180, level: "medium", state: .light), anchors: anchors,
            planningAt: at(600), planningDue: false, dayEndsAt: at(900), tomorrowAnchor: tomorrow
        ).lockScreenAnchorDisplay(time: time)
    }

    // MARK: Open

    @Test func anOpenWindowSaysUntilWhenItEnds() {
        let d = lock([window("Dhuhr", .open, from: -30, to: 40, progress: 0.4), window("Asr", .upcoming, from: 41, to: 100)])
        #expect(d.inline == "Dhuhr · until t+40")
        #expect(d.circular == .init(label: "Dhuhr", value: "t+40", ring: .progress(0.4)))
        #expect(d.rectangular == .init(title: "Dhuhr · until t+40", subtitle: "Asr opens t+41", bar: .init(fill: 0.4, style: .accent)))
    }

    @Test func anOpenWindowWithNothingAfterItHasNoSecondLine() {
        let d = lock([window("Isha", .open, from: -30, to: 40)])
        #expect(d.rectangular.subtitle == nil)
    }

    // MARK: Closing soon

    @Test func aClosingWindowKeepsItsAccentAndSaysHowLongIsLeft() {
        let d = lock([window("Asr", .closingSoon, from: -100, to: 20, progress: 0.85)])
        #expect(d.inline == "Asr · until t+20")
        #expect(d.rectangular == .init(title: "Asr · until t+20", subtitle: "closes in 20 min", bar: .init(fill: 0.85, style: .accent)))
        #expect(d.circular.ring == .progress(0.85))
    }

    @Test func theMinutesLeftRoundUpAndNeverReadZero() {
        #expect(lock([window("Asr", .closingSoon, from: -100, to: 0.4)]).rectangular.subtitle == "closes in 1 min")
        #expect(lock([window("Asr", .closingSoon, from: -100, to: 14.2)]).rectangular.subtitle == "closes in 15 min")
    }

    // MARK: Upcoming

    @Test func anUpcomingWindowSaysWhenItOpensAndHasAnOutlineRing() {
        let d = lock([window("School run", .upcoming, from: 60, to: 90, progress: 0)])
        #expect(d.inline == "School run · from t+60")
        #expect(d.circular == .init(label: "opens", value: "t+60", ring: .outline))
        #expect(d.rectangular == .init(title: "School run", subtitle: "opens t+60", bar: .init(fill: 0, style: .outline)))
    }

    // MARK: Needs attention and none left

    @Test func aWindowClosedUnmarkedIsAPlainFactWithANeutralFullBar() {
        let d = lock([window("Bin night", .needsAttention, from: -180, to: -60, progress: 1)])
        #expect(d.inline == "Bin night · not marked yet")
        #expect(d.circular == .init(label: "Bin night", value: "t-60", ring: .neutral))
        #expect(d.rectangular == .init(title: "Bin night", subtitle: "Not marked yet", bar: .init(fill: 1, style: .neutral)))
    }

    @Test func nothingLeftTodaySaysSoAndNamesTomorrowsFirstWhenThereIsOne() {
        let d = lock([], tomorrow: window("Fajr", .upcoming, from: 600, to: 660, progress: 0))
        #expect(d.inline == "Nothing more today")
        #expect(d.circular == .init(label: "Fajr", value: "t+600", ring: .none))
        #expect(d.rectangular == .init(title: "Nothing more today", subtitle: "Fajr tomorrow, t+600", bar: nil))
    }

    @Test func nothingLeftAndNothingTomorrowIsJustCalm() {
        let d = lock([])
        #expect(d.circular == .init(label: "Anchors", value: "None", ring: .none))
        #expect(d.rectangular == .init(title: "Nothing more today", subtitle: nil, bar: nil))
    }

    @Test func theBarFillIsKeptWithinZeroAndOne() {
        #expect(lock([window("A", .open, from: -1, to: 5, progress: 1.7)]).rectangular.bar?.fill == 1)
        #expect(lock([window("A", .open, from: -1, to: 5, progress: -0.2)]).rectangular.bar?.fill == 0)
    }

    @Test func anEmptySnapshotIsACalmNothingLeft() {
        let d = WidgetSnapshot.empty(at: now).lockScreenAnchorDisplay(time: time)
        #expect(d.inline == "Nothing more today")
        #expect(d.rectangular.subtitle == nil)
        #expect(WidgetSnapshot.empty(at: now).todayWidgetDisplay.mood == .blank)
    }

    @Test func theCircularUsesTheShortTimeAndTheOthersTheFullOne() {
        let snap = WidgetSnapshot(
            generatedAt: now, day: "d", isReadOnly: false, tasksLeft: 0, tasksDone: 0, tasks: [], moreTasks: 0,
            capacity: .init(plannedMinutes: 0, budgetMinutes: 1, level: "medium", state: .light),
            anchors: [window("Dhuhr", .open, from: -5, to: 40)], planningAt: at(600), planningDue: false, dayEndsAt: at(900))
        let d = snap.lockScreenAnchorDisplay(time: { _ in "1:24 pm" }, shortTime: { _ in "1:24" })
        #expect(d.circular.value == "1:24")
        #expect(d.inline == "Dhuhr · until 1:24 pm")
        #expect(d.rectangular.title == "Dhuhr · until 1:24 pm")
    }
}
