import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The words, routing, diff and permission rules around the planner (module 6).
@MainActor
struct NotificationDeliveryTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }
    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }

    // MARK: Words

    @Test func everyKindHasCalmWordsAndNeverUrgency() {
        let kinds: [NotificationKind] = [
            .planningPrompt(forDate: d(16)), .morningNudge, .anchorStart(title: "Asr", leadMinutes: 0),
            .anchorStart(title: "School run · Drop-off", leadMinutes: 10), .anchorClosing(title: "Asr", minutesBefore: 15),
            .habitReminder(title: "Water"), .trialEnding(day: 12), .trialEnding(day: 14), .trialEnding(day: 15),
        ]
        for kind in kinds {
            let c = NotificationMessages.content(for: kind)
            #expect(!c.title.isEmpty && !c.body.isEmpty)
            for word in ["urgent", "hurry", "don't miss", "last chance", "!", "overdue", "missed"] {
                #expect(!(c.title + " " + c.body).lowercased().contains(word), "\(kind): \(word)")
            }
        }
    }

    @Test func anAnchorReminderNamesItAndSaysWhenItOpensOrCloses() {
        #expect(NotificationMessages.content(for: .anchorStart(title: "Asr", leadMinutes: 0)) == NotificationContent(title: "Asr", body: "Its window is open now."))
        #expect(NotificationMessages.content(for: .anchorStart(title: "School run · Drop-off", leadMinutes: 10)).body == "Opens in 10 min.")
        #expect(NotificationMessages.content(for: .anchorClosing(title: "Asr", minutesBefore: 15)).body == "Closes in 15 min.")
        #expect(NotificationMessages.content(for: .habitReminder(title: "Water")).title == "Water")
    }

    @Test func theTrialMessagesDifferByDay() {
        let titles = [12, 14, 15].map { NotificationMessages.content(for: .trialEnding(day: $0)).title }
        #expect(Set(titles).count == 3)
        #expect(titles[1].contains("tomorrow") && titles[2].contains("ended"))
        #expect(NotificationMessages.content(for: .trialEnding(day: 13)).title == titles[0])
    }

    // MARK: Routing

    @Test func aTapRoutesByTheNotificationsId() {
        #expect(NotificationRoute.route(forID: "planning:2026-10-16") == .planning(d(16)))
        #expect(NotificationRoute.route(forID: "planning:nonsense") == .today)
        #expect(NotificationRoute.route(forID: "morning:2026-10-15") == .today)
        #expect(NotificationRoute.route(forID: "anchor:abc|2026-10-15|asr:start") == .today)
        #expect(NotificationRoute.route(forID: "habit:abc:2026-10-15") == .today)
        #expect(NotificationRoute.route(forID: "trial:14") == .subscription)
        #expect(NotificationRoute.route(forID: "") == .today)
        #expect(NotificationRoute.route(forID: "something-else") == .today)
    }

    // MARK: Diff

    private func planned(_ id: String, _ fire: Date, _ kind: NotificationKind) -> PlannedNotification {
        PlannedNotification(id: id, fireDate: fire, kind: kind, priority: 0)
    }
    private func pending(_ p: PlannedNotification, fire: Date? = nil, content: NotificationContent? = nil) -> PendingNotification {
        PendingNotification(id: p.id, fireDate: fire ?? p.fireDate, content: content ?? NotificationMessages.content(for: p.kind))
    }

    @Test func nothingChangesWhenThePlanMatchesWhatIsPending() {
        let a = planned("morning:2026-10-16", at(16, 8), .morningNudge)
        let b = planned("habit:x:2026-10-15", at(15, 18), .habitReminder(title: "Water"))
        let changes = NotificationDiff.make(planned: [a, b], pending: [pending(a), pending(b)])
        #expect(changes.add.isEmpty && changes.remove.isEmpty)
    }

    @Test func newChangedAndNoLongerWantedAreTold() {
        let kept = planned("morning:2026-10-16", at(16, 8), .morningNudge)
        let moved = planned("planning:2026-10-16", at(15, 20), .planningPrompt(forDate: d(16)))
        let renamed = planned("habit:x:2026-10-15", at(15, 18), .habitReminder(title: "Drink water"))
        let fresh = planned("anchor:a:start", at(15, 17), .anchorStart(title: "Asr", leadMinutes: 0))
        let changes = NotificationDiff.make(
            planned: [kept, moved, renamed, fresh],
            pending: [pending(kept), pending(moved, fire: at(15, 19)),
                      pending(renamed, content: NotificationMessages.content(for: .habitReminder(title: "Water"))),
                      PendingNotification(id: "habit:gone:2026-10-15", fireDate: at(15, 12), content: NotificationMessages.content(for: .habitReminder(title: "Done")))])
        #expect(Set(changes.add.map(\.id)) == ["planning:2026-10-16", "habit:x:2026-10-15", "anchor:a:start"])
        #expect(changes.remove == ["habit:gone:2026-10-15"])
    }

    @Test func aSubSecondDriftIsNotAChange() {
        let a = planned("morning:2026-10-16", at(16, 8), .morningNudge)
        let changes = NotificationDiff.make(planned: [a], pending: [pending(a, fire: a.fireDate.addingTimeInterval(0.4))])
        #expect(changes.add.isEmpty)
        #expect(NotificationDiff.make(planned: [a], pending: [pending(a, fire: a.fireDate.addingTimeInterval(2))]).add.count == 1)
    }

    @Test func aPlanThatEmptiesRemovesEverythingPending() {
        let a = planned("morning:2026-10-16", at(16, 8), .morningNudge)
        let changes = NotificationDiff.make(planned: [], pending: [pending(a)])
        #expect(changes.remove == [a.id] && changes.add.isEmpty)
    }

    // MARK: What a denial costs

    private func habit(_ c: ModelContext, _ title: String, reminder: Int?, archived: Bool = false, created: Int = 0) {
        let h = Habit(title: title)
        h.createdAt = at(1, 0).addingTimeInterval(Double(created))
        h.isArchived = archived
        let w = HabitTimeWindow()
        w.reminderMinute = reminder
        h.windows = [w]
        c.insert(h)
    }

    @Test func theWarningCardListsOnlyWhatWouldHaveArrived() throws {
        let c = try context()
        #expect(try ReminderStatus.undelivered(in: c, morningEnabled: false) == ["The evening planning prompt"])
        #expect(try ReminderStatus.undelivered(in: c, morningEnabled: true) == ["The evening planning prompt", "The morning list"])

        var salah = PrayerRuleDraft(countryCode: "GB")
        salah.location = PrayerConfig.Location(mode: "manual", latitude: 52.64, longitude: -1.14, name: "Leicester")
        try PrayerEditing.create(salah, in: c, now: at(1, 0))
        var quiet = AnchorRuleDraft.preset(.binNight, today: d(1))
        quiet.remindAtStart = false
        try AnchorEditing.create(quiet, in: c, now: at(1, 1))                                 // no reminder: not listed
        var school = AnchorRuleDraft.preset(.schoolRun, today: d(1))
        school.remindAtStart = true
        try AnchorEditing.create(school, in: c, now: at(1, 2))
        habit(c, "Water", reminder: 600, created: 0)
        habit(c, "Medication", reminder: 480, created: 1)
        habit(c, "Reading", reminder: nil, created: 2)                                         // no reminder time: not listed
        habit(c, "Old", reminder: 700, archived: true, created: 3)                             // archived: not listed
        let lines = try ReminderStatus.undelivered(in: c, morningEnabled: true)
        #expect(lines == ["The evening planning prompt", "The morning list", "Salah reminders", "School run reminders", "Water and Medication reminders"])
        habit(c, "Journal", reminder: 900, created: 4)
        #expect(try ReminderStatus.undelivered(in: c, morningEnabled: false).last == "Water, Medication and Journal reminders")
    }

    @Test func anArchivedRuleAndAnUnreadableOneAreNotListed() throws {
        let c = try context()
        var salah = PrayerRuleDraft(countryCode: "GB")
        salah.location = PrayerConfig.Location(mode: "manual", latitude: 52.64, longitude: -1.14, name: "Leicester")
        let rule = try PrayerEditing.create(salah, in: c, now: at(1, 0))
        rule.isArchived = true
        let broken = AnchorRule(title: "Swimming"); broken.configData = #"{"version":99}"#; c.insert(broken)
        #expect(try ReminderStatus.undelivered(in: c, morningEnabled: false) == ["The evening planning prompt"])
    }

    // MARK: The Today banner

    private func banner(
        permission: NotificationPermission = .denied, on: Bool = true, now: Date? = nil, planning: Int = 20 * 60,
        settled: Bool = false, dismissed: CalendarDate? = nil, dont: Bool = false
    ) -> Bool {
        ReminderStatus.showsBanner(permission: permission, remindersOnThisDevice: on, now: now ?? at(15, 21), boundary: boundary,
                                   planningMinute: planning, tonightSettled: settled, dismissedOn: dismissed, dontRemind: dont)
    }

    @Test func theBannerShowsOnlyWhenThisDeviceShouldRemindButCannot() {
        #expect(banner())
        #expect(banner(permission: .notAsked))
        #expect(!banner(permission: .granted))
        #expect(!banner(on: false))                                  // quiet by choice: no banner
    }

    @Test func theBannerWaitsForThePlanningTimeAndStopsOnceTonightIsSettled() {
        #expect(!banner(now: at(15, 19, 59)))
        #expect(banner(now: at(15, 20)))
        #expect(!banner(settled: true))
    }

    @Test func theBannerIsDismissedForTheDayAndForeverOnRequest() {
        #expect(!banner(dismissed: d(15)))
        #expect(banner(dismissed: d(14)))                            // yesterday's dismissal is over
        #expect(!banner(dont: true))
    }
}
