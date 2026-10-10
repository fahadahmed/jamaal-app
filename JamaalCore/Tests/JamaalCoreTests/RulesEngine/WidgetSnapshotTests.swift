import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The widget read model (docs/architecture/widgets-and-watch.md): what Today would say, as a small Codable value.
@MainActor
struct WidgetSnapshotTests {

    private func make(_ w: TaskWorld, now: Date, access: AccessState = .trial(daysLeft: 9), maxTasks: Int = 5, maxAnchors: Int = 3) throws -> WidgetSnapshot {
        try WidgetSnapshot.make(in: w.context, now: now, access: access, maxTasks: maxTasks, maxAnchors: maxAnchors, timeZone: TimeZone(identifier: "UTC")!)
    }

    @discardableResult
    private func anchor(
        _ w: TaskWorld, _ title: String, rule: String? = nil, from: Date, to: Date, status: AttendanceStatus = .pending, day: Int = 15
    ) -> Anchor {
        let a = Anchor(title: title)
        a.occurrenceDate = w.d(day).storedDate
        a.windowStart = from; a.windowEnd = to
        a.status = status
        if let rule { let r = AnchorRule(title: rule); w.context.insert(r); a.rule = r }
        w.context.insert(a)
        return a
    }

    // MARK: Tasks and capacity

    @Test func theHeadlineCountsWhatIsLeftAndWhatIsDone() throws {
        let w = try TaskWorld()
        let done = w.task("Done", due: 15)
        w.task("A", due: 15); w.task("B", due: 15)
        _ = TaskActions.complete(done, now: w.at(15, 9), boundary: w.boundary, context: w.context)
        let s = try make(w, now: w.at(15, 10))
        #expect(s.tasksLeft == 2)
        #expect(s.tasksDone == 1)
        #expect(!s.isBlankDay && !s.isAllDone)
    }

    @Test func onlyTheFirstFewTasksAreCarriedAndTheRestAreCounted() throws {
        let w = try TaskWorld()
        for n in 1...7 { w.task("Task \(n)", due: 15) }
        let s = try make(w, now: w.at(15, 10), maxTasks: 5)
        #expect(s.tasksLeft == 7)
        #expect(s.tasks.count == 5)
        #expect(s.moreTasks == 2)
        let shown = try TodayDay.overview(in: w.context, now: w.at(15, 10), timeZone: TimeZone(identifier: "UTC")!).shown.prefix(5).map(\.title)
        #expect(s.tasks.map(\.title) == Array(shown), "in Today's own order")
    }

    @Test func aTaskLineCarriesItsTitleEffortAndCategoryColour() throws {
        let w = try TaskWorld()
        let category = TaskCategory(name: "Work"); category.colorKey = "blue"
        w.context.insert(category)
        let t = w.task("Draft the review", due: 15, minutes: 60)
        t.category = category
        w.task("No estimate", due: 15, minutes: nil)
        let s = try make(w, now: w.at(15, 10))
        let line = try #require(s.tasks.first { $0.title == "Draft the review" })
        #expect(line.id == t.id)
        #expect(line.effortMinutes == 60)
        #expect(line.categoryColorKey == "blue")
        let bare = try #require(s.tasks.first { $0.title == "No estimate" })
        #expect(bare.effortMinutes == nil && bare.categoryColorKey == nil)
    }

    @Test func theCapacityIsThePlannedMinutesAgainstTheBudget() throws {
        let w = try TaskWorld()
        w.task("A", due: 15, minutes: 60); w.task("B", due: 15, minutes: 60)
        let s = try make(w, now: w.at(15, 10))
        #expect(s.capacity.plannedMinutes == 120)
        #expect(s.capacity.budgetMinutes == 180)
        #expect(s.capacity.level == "medium")
        #expect(s.capacity.state == .light)
    }

    @Test func aBlankDayAndAnAllDoneDayAreTold() throws {
        let w = try TaskWorld()
        let blank = try make(w, now: w.at(15, 10))
        #expect(blank.isBlankDay && !blank.isAllDone)
        let t = w.task("Only", due: 15)
        _ = TaskActions.complete(t, now: w.at(15, 9), boundary: w.boundary, context: w.context)
        let done = try make(w, now: w.at(15, 10))
        #expect(done.isAllDone && !done.isBlankDay)
    }

    // MARK: Anchors

    @Test func theOpenAnchorComesFirstThenTheUpcomingOneThenOneLeftUnmarked() throws {
        let w = try TaskWorld()
        anchor(w, "Dhuhr", rule: "Salah", from: w.at(15, 13), to: w.at(15, 15))                       // open at 13:30
        anchor(w, "Asr", rule: "Salah", from: w.at(15, 16), to: w.at(15, 17))                         // upcoming
        anchor(w, "Bins", from: w.at(15, 8), to: w.at(15, 9))                                         // closed, never marked
        anchor(w, "Fajr", rule: "Salah", from: w.at(15, 5), to: w.at(15, 6), status: .attended)       // done: not listed
        anchor(w, "School run", from: w.at(15, 7), to: w.at(15, 8), status: .skipped)                 // skipped: not listed
        let s = try make(w, now: w.at(15, 13, 30))
        #expect(s.anchors.map(\.name) == ["Dhuhr", "Asr", "Bins"])
        #expect(s.anchors.map(\.phase) == [.open, .upcoming, .needsAttention])
        #expect(s.nextAnchor?.name == "Dhuhr")
    }

    @Test func aWindowInItsLastQuarterIsClosingSoon() throws {
        let w = try TaskWorld()
        anchor(w, "Dhuhr", rule: "Salah", from: w.at(15, 13), to: w.at(15, 15))
        #expect(try make(w, now: w.at(15, 14, 29)).anchors.first?.phase == .open)
        #expect(try make(w, now: w.at(15, 14, 30)).anchors.first?.phase == .closingSoon)
    }

    @Test func anAnchorKeepsItsRulesTitleAndHowFarThroughItsWindowItIs() throws {
        let w = try TaskWorld()
        anchor(w, "Pick-up", rule: "School run", from: w.at(15, 15), to: w.at(15, 16))
        let s = try make(w, now: w.at(15, 15, 30))
        let a = try #require(s.anchors.first)
        #expect(a.name == "Pick-up")
        #expect(a.ruleTitle == "School run")
        #expect(a.progress == 0.5)
        #expect(a.start == w.at(15, 15) && a.end == w.at(15, 16))
    }

    @Test func aOneOffHasNoRuleTitle() throws {
        let w = try TaskWorld()
        anchor(w, "Dentist", from: w.at(15, 16), to: w.at(15, 17))
        #expect(try make(w, now: w.at(15, 10)).anchors.first?.ruleTitle == nil)
    }

    @Test func theAnchorListIsCappedAndTheEarliestRelevantOnesWin() throws {
        let w = try TaskWorld()
        for h in 12...17 { anchor(w, "A\(h)", from: w.at(15, h), to: w.at(15, h, 30)) }
        let s = try make(w, now: w.at(15, 11), maxAnchors: 3)
        #expect(s.anchors.map(\.name) == ["A12", "A13", "A14"])
    }

    @Test func noAnchorsLeftTodayMeansNoNextAnchor() throws {
        let w = try TaskWorld()
        anchor(w, "Fajr", rule: "Salah", from: w.at(15, 5), to: w.at(15, 6), status: .attended)
        #expect(try make(w, now: w.at(15, 10)).nextAnchor == nil)
    }

    // MARK: Planning, access and the day

    @Test func planningIsDueFromTheEveningTimeAndOfferedOnlyWhenNotReadOnly() throws {
        let w = try TaskWorld()
        let morning = try make(w, now: w.at(15, 10))
        #expect(!morning.planningDue && !morning.showsPlanTomorrow)
        #expect(morning.planningAt == w.at(15, 20), "20:00 by default")

        let evening = try make(w, now: w.at(15, 21))
        #expect(evening.planningDue && evening.showsPlanTomorrow)

        let locked = try make(w, now: w.at(15, 21), access: .readOnly)
        #expect(locked.isReadOnly && locked.planningDue && !locked.showsPlanTomorrow, "read-only drops the link, keeps the data")
    }

    @Test func theDayEndsAtTheNextRolloverNotAlwaysAtMidnight() throws {
        let w = try TaskWorld()
        let first = try make(w, now: w.at(15, 10))
        #expect(first.dayEndsAt == w.at(16, 0))
        let settings = UserSettings()
        settings.rolloverMinute = 180
        w.context.insert(settings)
        let s = try make(w, now: w.at(15, 10))
        #expect(s.dayEndsAt == w.at(16, 3))
    }

    // MARK: Codable

    @Test func theSnapshotSurvivesBeingEncodedAndDecoded() throws {
        let w = try TaskWorld()
        w.task("A", due: 15, minutes: 45)
        anchor(w, "Dhuhr", rule: "Salah", from: w.at(15, 13), to: w.at(15, 15))
        let s = try make(w, now: w.at(15, 13, 30))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(WidgetSnapshot.self, from: try encoder.encode(s))
        #expect(back == s)
    }
}
