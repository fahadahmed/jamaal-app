import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Generation (docs/schema/anchor.md, docs/architecture/rules-engine.md module 3): a rule's
/// recurrence and slots give window-bound instances, keyed by (rule, occurrenceDate, slotKey).
@MainActor
struct AnchorGeneratorTests {

    private func schoolRun(_ w: AnchorWorld, createdAt: Date? = nil, exceptions: [AnchorException] = [], endDate: CalendarDate? = nil,
                           reminder: AnchorReminder? = nil) -> AnchorRule {
        let config = w.scheduled(
            .weekly(weekdays: [1, 2, 3, 4, 5]),
            slots: [w.slot("drop", "Drop-off", "08:15", minutes: 30), w.slot("pick", "Pick-up", "15:00", minutes: 30)],
            endDate: endDate, reminder: reminder, exceptions: exceptions
        )
        return w.rule("School run", config, effort: 30, createdAt: createdAt)
    }

    // MARK: Preview (dry run, no writes)

    @Test func eachOccurrenceDayGivesOneInstancePerSlot() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        let preview = AnchorGenerator.preview(rule: rule, days: [w.d(5), w.d(10)], boundary: w.boundary)   // Mon, Sat
        #expect(preview.map(\.slotKey) == ["drop", "pick"])
        #expect(preview.map(\.occurrenceDate) == [w.d(5), w.d(5)])
        #expect(preview[0].windowStart == w.at(5, 8, 15))
        #expect(preview[0].windowEnd == w.at(5, 8, 45))
        #expect(preview[1].windowStart == w.at(5, 15))
        #expect(preview[0].effortMinutes == 30)
        #expect(preview[0].title == "Drop-off")
    }

    @Test func aSlotWithNoLabelTakesTheRulesTitle() throws {
        let w = try AnchorWorld()
        let rule = w.rule("Bin night", w.scheduled(.weekly(weekdays: [3]), slots: [w.slot("a", "", "19:00", minutes: 180)]))
        let preview = AnchorGenerator.preview(rule: rule, days: [w.d(7)], boundary: w.boundary)
        #expect(preview.first?.title == "Bin night")
    }

    @Test func remindersAreCopiedFromTheRule() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w, reminder: AnchorReminder(atStart: true, beforeEndMinutes: 10))
        let first = try #require(AnchorGenerator.preview(rule: rule, days: [w.d(5)], boundary: w.boundary).first)
        #expect(first.remindBeforeStartMinutes == 0)
        #expect(first.remindBeforeEndMinutes == 10)
        let quiet = try #require(AnchorGenerator.preview(rule: schoolRun(w), days: [w.d(5)], boundary: w.boundary).first)
        #expect(quiet.remindBeforeStartMinutes == nil)
        #expect(quiet.remindBeforeEndMinutes == nil)
    }

    @Test func exceptionsEndDateAndTheCreationFloorSuppressInstances() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w, createdAt: w.at(7, 9), exceptions: [AnchorException(from: w.d(8), to: w.d(8), reason: "holiday")], endDate: w.d(9))
        let days = [5, 6, 7, 8, 9, 12].map { w.d($0) }
        let preview = AnchorGenerator.preview(rule: rule, days: days, boundary: w.boundary)
        // 5 and 6: windows ended before the rule existed. 7: the 08:15 window ended before 09:00, but 15:00 didn't.
        // 8: excepted. 9: the last day. 12: after the end date.
        #expect(preview.map { "\($0.occurrenceDate.day)-\($0.slotKey)" } == ["7-pick", "9-drop", "9-pick"])
    }

    @Test func anAllDaySlotCoversTheWholeLogicalDay() throws {
        let w = try AnchorWorld()
        let rule = w.rule("Plants", w.scheduled(.everyNDays(n: 3, startDate: w.d(5)), slots: [w.slot("w", "", "00:00", minutes: 1, allDay: true)]), source: .plantWatering)
        let item = try #require(AnchorGenerator.preview(rule: rule, days: [w.d(8)], boundary: w.boundary).first)
        #expect(item.windowStart == w.at(8, 0))
        #expect(item.windowEnd == w.at(9, 0))
    }

    @Test func aWindowMayCrossMidnightAndStillBelongsToTheDayItStarts() throws {
        let w = try AnchorWorld()
        let rule = w.rule("Late", w.scheduled(.weekly(weekdays: [1]), slots: [w.slot("a", "Late", "22:30", minutes: 180)]))
        let item = try #require(AnchorGenerator.preview(rule: rule, days: [w.d(5)], boundary: w.boundary).first)
        #expect(item.windowEnd == w.at(6, 1, 30))
        #expect(item.occurrenceDate == w.d(5))
    }

    @Test func withALateRolloverAnEarlyMorningSlotBelongsToTheDayBefore() throws {
        let w = try AnchorWorld(rolloverMinute: 180)               // the day rolls over at 03:00
        let rule = w.rule("Night shift", w.scheduled(.weekly(weekdays: [1]), slots: [w.slot("a", "Handover", "01:00", minutes: 30)]))
        let item = try #require(AnchorGenerator.preview(rule: rule, days: [w.d(5)], boundary: w.boundary).first)
        #expect(item.windowStart == w.at(5, 1))
        #expect(item.occurrenceDate == w.d(4))
    }

    @Test func disabledArchivedAndUnreadableRulesGenerateNothing() throws {
        let w = try AnchorWorld()
        let off = schoolRun(w); off.isEnabled = false
        let archived = schoolRun(w); archived.isArchived = true
        let broken = AnchorRule(title: "Broken"); broken.configData = "garbage"
        for rule in [off, archived, broken] {
            #expect(AnchorGenerator.preview(rule: rule, days: [w.d(5)], boundary: w.boundary).isEmpty)
        }
    }

    // MARK: Sync (writes today and tomorrow)

    private func sync(_ w: AnchorWorld, nowDay: Int = 5, hour: Int = 7) throws -> AnchorSyncReport {
        try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: w.at(nowDay, hour))
    }

    @Test func createsTodayAndTomorrowOnceAndSyncingAgainChangesNothing() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        let first = try sync(w)                                       // Monday 07:00
        #expect(first.created == 4)                                    // Mon and Tue, two slots each
        #expect(try w.anchors().count == 4)
        #expect(try w.anchors().allSatisfy { $0.rule?.id == rule.id })
        let second = try sync(w)
        #expect(second == AnchorSyncReport())
        #expect(try w.anchors().count == 4)
    }

    @Test func aRuleCreatedLaterInTheDayNeverGeneratesWindowsThatAlreadyClosed() throws {
        let w = try AnchorWorld()
        _ = schoolRun(w, createdAt: w.at(5, 14, 5))
        _ = try sync(w, hour: 14)
        let titles = try w.anchors().map { "\($0.occurrenceDate == w.d(5).storedDate ? "today" : "tomorrow") \($0.title)" }
        #expect(titles == ["today Pick-up", "tomorrow Drop-off", "tomorrow Pick-up"])   // today's 08:15 window had closed
    }

    @Test func editingARuleUpdatesPendingInstancesInPlace() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        _ = try sync(w)
        let before = Set(try w.anchors().map(\.id))
        var config = w.scheduled(.weekly(weekdays: [1, 2, 3, 4, 5]),
                                 slots: [w.slot("drop", "Drop-off", "08:30", minutes: 30), w.slot("pick", "Pick-up", "15:00", minutes: 30)])
        config.reminder = AnchorReminder(atStart: true, beforeEndMinutes: nil)
        rule.configData = config.json
        rule.effortMinutes = 20
        let report = try sync(w)
        #expect(report.updated == 4)
        #expect(Set(try w.anchors().map(\.id)) == before)               // same rows, edited
        let drop = try #require(try w.anchors().first { $0.slotKey == "drop" })
        #expect(drop.windowStart == w.at(5, 8, 30))
        #expect(drop.effortMinutes == 20)
        #expect(drop.remindBeforeStartMinutes == 0)
    }

    @Test func decidedInstancesAreNeverRewrittenOrResurrected() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        _ = try sync(w)
        let drop = try #require(try w.anchors().first { $0.slotKey == "drop" && $0.occurrenceDate == w.d(5).storedDate })
        drop.status = .skipped
        drop.resolvedAt = w.at(5, 8)
        rule.configData = w.scheduled(.weekly(weekdays: [1, 2, 3, 4, 5]),
                                      slots: [w.slot("drop", "Drop-off", "09:00", minutes: 30), w.slot("pick", "Pick-up", "15:00", minutes: 30)]).json
        _ = try sync(w)
        #expect(drop.status == .skipped)
        #expect(drop.windowStart == w.at(5, 8, 15))                    // untouched
        #expect(try w.anchors().filter { $0.slotKey == "drop" && $0.occurrenceDate == w.d(5).storedDate }.count == 1)   // not regenerated
    }

    @Test func addingAnExceptionRemovesPendingInstancesButKeepsDecidedOnes() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        _ = try sync(w)
        let attended = try #require(try w.anchors().first { $0.slotKey == "drop" && $0.occurrenceDate == w.d(5).storedDate })
        attended.status = .attended
        attended.resolvedAt = w.at(5, 8, 20)
        var config = w.scheduled(.weekly(weekdays: [1, 2, 3, 4, 5]),
                                 slots: [w.slot("drop", "Drop-off", "08:15", minutes: 30), w.slot("pick", "Pick-up", "15:00", minutes: 30)])
        config.exceptions = [AnchorException(from: w.d(5), to: w.d(6), reason: "holiday")]
        rule.configData = config.json
        let report = try sync(w)
        #expect(report.removed == 3)
        #expect(try w.anchors().map(\.id) == [attended.id])
    }

    @Test func aRemovedSlotRemovesItsPendingInstancesOnly() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        _ = try sync(w)
        rule.configData = w.scheduled(.weekly(weekdays: [1, 2, 3, 4, 5]), slots: [w.slot("drop", "Drop-off", "08:15", minutes: 30)]).json
        _ = try sync(w)
        #expect(try w.anchors().allSatisfy { $0.slotKey == "drop" })
        #expect(try w.anchors().count == 2)
    }

    @Test func disablingOrArchivingARuleRemovesItsFuturePendingInstances() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        _ = try sync(w)
        let kept = try #require(try w.anchors().first)
        kept.status = .attended
        rule.isEnabled = false
        _ = try sync(w)
        #expect(try w.anchors().map(\.id) == [kept.id])
        rule.isEnabled = true
        rule.isArchived = true
        _ = try sync(w)
        #expect(try w.anchors().map(\.id) == [kept.id])
    }

    @Test func aRuleThatNeedsAttentionIsLeftAlone() throws {
        let w = try AnchorWorld()
        let rule = schoolRun(w)
        _ = try sync(w)
        rule.configData = #"{"version":3}"#                             // written by a newer app
        let report = try sync(w)
        #expect(report == AnchorSyncReport())
        #expect(try w.anchors().count == 4)                              // nothing deleted
    }

    @Test func oneOffAnchorsAreNeverTouched() throws {
        let w = try AnchorWorld()
        let oneOff = w.anchor("Dentist", from: w.at(6, 15))
        _ = schoolRun(w)
        _ = try sync(w)
        #expect(try w.anchors().contains { $0.id == oneOff.id })
    }
}
