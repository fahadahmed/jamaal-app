import Foundation
import Testing
@testable import JamaalCore

/// `AnchorRule.configData` (docs/schema/anchor.md): two families, versioned. Anything that can't
/// be read is "needs attention": never generated, never deleted.
@MainActor
struct AnchorConfigTests {

    private func d(_ day: Int, month: Int = 10) -> CalendarDate { CalendarDate(year: 2026, month: month, day: day)! }

    private let documented = """
    {
      "version": 1,
      "recurrence": { "kind": "weekly", "weekdays": [1,2,3,4,5] },
      "slots": [
        { "id": "3F2A", "label": "Drop-off", "start": "08:15", "windowMinutes": 30 },
        { "id": "9C71", "label": "Pick-up",  "start": "15:00", "windowMinutes": 30 }
      ],
      "endDate": null,
      "reminder": { "atStart": false, "beforeEndMinutes": null },
      "exceptions": [
        { "from": "2026-12-15", "to": "2027-01-27", "reason": "holiday" },
        { "from": "2027-03-02", "to": null, "reason": "illness" }
      ]
    }
    """

    // MARK: Decoding

    @Test func decodesTheDocumentedScheduledShape() throws {
        guard case .scheduled(let config) = AnchorRuleConfig.decode(sourceKey: "schoolRun", configData: documented) else {
            Issue.record("expected a scheduled config"); return
        }
        #expect(config.recurrence == .weekly(weekdays: [1, 2, 3, 4, 5]))
        #expect(config.slots.map(\.label) == ["Drop-off", "Pick-up"])
        #expect(config.slots[0].start == "08:15")
        #expect(config.slots[0].allDay == false)               // optional, defaults to false
        #expect(config.endDate == nil)
        #expect(config.exceptions.count == 2)
        #expect(config.exceptions[1].to == nil)
        #expect(config.exceptions[0].reasonKind == .holiday)
    }

    @Test func decodesEachRecurrenceKind() throws {
        func recurrence(_ json: String) -> AnchorRecurrence? {
            let text = #"{"version":1,"recurrence":\#(json),"slots":[]}"#
            if case .scheduled(let c) = AnchorRuleConfig.decode(sourceKey: "custom", configData: text) { return c.recurrence }
            return nil
        }
        #expect(recurrence(#"{"kind":"everyNDays","n":3,"startDate":"2026-10-05"}"#) == .everyNDays(n: 3, startDate: d(5)))
        #expect(recurrence(#"{"kind":"everyNWeeks","n":2,"weekdays":[3],"startDate":"2026-10-05"}"#) == .everyNWeeks(n: 2, weekdays: [3], startDate: d(5)))
        #expect(recurrence(#"{"kind":"afterLast","minDays":3,"maxDays":4,"startDate":"2026-10-05"}"#) == .afterLast(minDays: 3, maxDays: 4, startDate: d(5)))
    }

    @Test func decodesThePrayerShape() throws {
        let json = """
        {"version":1,"method":"northAmerica","madhab":"shafi","highLatitude":"middleOfNight","ishaEnds":"midnight",
         "fridayLabel":true,"reminder":{"atStart":true,"beforeEndMinutes":null},
         "prayers":["fajr","dhuhr","asr","maghrib","isha"],
         "adjustmentsMinutes":{"fajr":0,"dhuhr":2,"asr":0,"maghrib":0,"isha":0},
         "location":{"mode":"device","latitude":-36.85,"longitude":174.76,"name":"Auckland"}}
        """
        guard case .prayer(let config) = AnchorRuleConfig.decode(sourceKey: "prayerWindow", configData: json) else {
            Issue.record("expected a prayer config"); return
        }
        #expect(config.method == "northAmerica")
        #expect(config.fridayLabel)
        #expect(config.reminder?.atStart == true)
        #expect(config.prayers == ["fajr", "dhuhr", "asr", "maghrib", "isha"])
        #expect(config.adjustmentsMinutes["dhuhr"] == 2)
        #expect(config.location?.name == "Auckland")
    }

    @Test func aNewerVersionNeedsAttentionAndIsNotAnError() {
        let result = AnchorRuleConfig.decode(sourceKey: "custom", configData: #"{"version":2,"recurrence":{"kind":"weekly","weekdays":[1]},"slots":[]}"#)
        #expect(result == .needsAttention(.newerVersion))
    }

    @Test(arguments: [
        "", "{}", "not json", "[]",
        #"{"version":1,"recurrence":{"kind":"yearly"},"slots":[]}"#,                                      // unknown kind
        #"{"version":1,"recurrence":{"kind":"weekly","weekdays":[]},"slots":[]}"#,                        // no weekdays
        #"{"version":1,"recurrence":{"kind":"weekly","weekdays":[8]},"slots":[]}"#,                       // bad weekday
        #"{"version":1,"recurrence":{"kind":"everyNDays","n":0,"startDate":"2026-10-05"},"slots":[]}"#,   // n < 1
        #"{"version":1,"recurrence":{"kind":"afterLast","minDays":4,"maxDays":3,"startDate":"2026-10-05"},"slots":[]}"#,
        #"{"version":1,"recurrence":{"kind":"weekly","weekdays":[1]},"slots":[{"id":"a","label":"","start":"25:99","windowMinutes":10}]}"#,
        #"{"version":1,"recurrence":{"kind":"weekly","weekdays":[1]},"slots":[{"id":"a","label":"","start":"08:00","windowMinutes":0}]}"#,
    ])
    func unreadableConfigNeedsAttention(json: String) {
        #expect(AnchorRuleConfig.decode(sourceKey: "custom", configData: json) == .needsAttention(.unreadable))
    }

    @Test func aRuleExposesItsConfigAndNeverRewritesWhatItCannotRead() throws {
        let rule = AnchorRule(title: "Newer")
        rule.configData = #"{"version":9,"anything":true}"#
        #expect(rule.config == .needsAttention(.newerVersion))
        #expect(rule.configData == #"{"version":9,"anything":true}"#)      // untouched
    }

    @Test func aScheduledConfigRoundTrips() throws {
        let original = ScheduledConfig(
            version: 1, recurrence: .everyNWeeks(n: 2, weekdays: [2, 4], startDate: d(5)),
            slots: [AnchorSlot(id: "x", label: "Bins", start: "19:00", windowMinutes: 180, allDay: false)],
            endDate: d(30), reminder: AnchorReminder(atStart: true, beforeEndMinutes: 15),
            exceptions: [AnchorException(from: d(12), to: nil, reason: "travel")]
        )
        guard case .scheduled(let decoded) = AnchorRuleConfig.decode(sourceKey: "binNight", configData: original.json) else {
            Issue.record("expected a scheduled config"); return
        }
        #expect(decoded == original)
    }

    // MARK: Recurrence

    @Test(arguments: [(5, true), (6, true), (9, true), (10, false), (11, false), (12, true)])   // Mon 5 … Fri 9, Sat 10, Sun 11, Mon 12
    func weeklyRecurrenceFollowsItsWeekdays(day: Int, expected: Bool) {
        #expect(AnchorRecurrence.weekly(weekdays: [1, 2, 3, 4, 5]).occurs(on: d(day)) == expected)
    }

    @Test(arguments: [(5, true), (6, false), (8, true), (11, true), (7, false), (2, false)])
    func everyNDaysCountsFromItsStartDate(day: Int, expected: Bool) {
        #expect(AnchorRecurrence.everyNDays(n: 3, startDate: d(5)).occurs(on: d(day)) == expected)    // 5, 8, 11…; never before the start
    }

    @Test(arguments: [(7, true), (14, false), (21, true), (8, false), (30, false)])
    func everyNWeeksCountsWeeksFromTheWeekOfItsStart(day: Int, expected: Bool) {
        // Start Mon 5 Oct; Wednesdays every 2nd week: 7 Oct (week 0), 21 Oct (week 2).
        #expect(AnchorRecurrence.everyNWeeks(n: 2, weekdays: [3], startDate: d(5)).occurs(on: d(day)) == expected)
    }

    @Test func afterLastIsNotCalendarBased() {
        #expect(!AnchorRecurrence.afterLast(minDays: 3, maxDays: 4, startDate: d(5)).occurs(on: d(8)))
    }

    // MARK: Exceptions and the end date

    @Test func exceptionsCoverTheirEndsAndOpenEndedOnesRunOn() {
        let config = ScheduledConfig(
            version: 1, recurrence: .weekly(weekdays: [1]), slots: [], endDate: d(30), reminder: nil,
            exceptions: [AnchorException(from: d(12), to: d(14), reason: "holiday"), AnchorException(from: d(20), to: nil, reason: "illness")]
        )
        #expect(!config.isExcepted(d(11)))
        #expect(config.isExcepted(d(12)))
        #expect(config.isExcepted(d(14)))
        #expect(!config.isExcepted(d(15)))
        #expect(config.isExcepted(d(25)))
        #expect(!config.isActive(on: d(31)))                           // past the end date
        #expect(config.isActive(on: d(19)))
        #expect(!config.isActive(on: d(13)))
    }
}
