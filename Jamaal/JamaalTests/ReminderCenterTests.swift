//
//  ReminderCenterTests.swift
//  JamaalTests
//

import Foundation
import SwiftData
import Testing
import JamaalCore
@testable import Jamaal

@MainActor
struct ReminderCenterTests {

    private func defaults() -> UserDefaults {
        let suite = "ReminderCenterTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private func store() throws -> ModelContext {
        let context = ModelContext(try JamaalSchema.makeContainer(inMemory: true))
        try Seeding.ensureSeeded(in: context, now: .now)
        return context
    }

    private func center(_ state: NotificationPermission, defaults: UserDefaults? = nil, isPhone: Bool = true) -> (ReminderCenter, FakeNotificationClient) {
        let client = FakeNotificationClient(state: state)
        return (ReminderCenter(client: client, defaults: defaults ?? self.defaults(), isPhone: isPhone), client)
    }

    /// 07:00 today, in the store's time zone.
    private func morning(_ context: ModelContext) -> Date {
        let boundary = TodayDay.boundary(in: context)
        return boundary.instant(of: boundary.logicalDate(at: .now), atMinute: 7 * 60)
    }

    @Test func aGrantedPhoneSchedulesTheEveningPromptsAndTheMorningList() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        await reminders.replan(in: context, now: morning(context))
        let pending = await client.pending()
        #expect(pending.filter { $0.id.hasPrefix("planning:") }.count == 5)
        #expect(pending.filter { $0.id.hasPrefix("morning:") }.count >= 4)
        #expect(reminders.scheduledCount == pending.count)
        #expect(!reminders.isBlocked)
    }

    @Test func aReplanWithNothingNewChangesNothing() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        let now = morning(context)
        await reminders.replan(in: context, now: now)
        let first = await client.pending()
        await reminders.replan(in: context, now: now)
        let second = await client.pending()
        #expect(Set(first.map(\.id)) == Set(second.map(\.id)) && first.count == second.count)
    }

    @Test func deniedSchedulesNothingAndIsBlocked() async throws {
        let context = try store()
        let (reminders, client) = center(.denied)
        await reminders.replan(in: context, now: morning(context))
        #expect(await client.pending().isEmpty)
        #expect(reminders.permission == .denied && reminders.isBlocked)
    }

    @Test func aDeviceThatIsQuietByChoiceSchedulesNothingAndIsNotBlocked() async throws {
        let context = try store()
        let (reminders, client) = center(.granted, isPhone: false)          // iPad and Mac default to off
        #expect(!reminders.remindersOnThisDevice)
        await reminders.replan(in: context, now: morning(context))
        #expect(await client.pending().isEmpty)
        let (denied, _) = center(.denied, isPhone: false)
        await denied.replan(in: context, now: morning(context))
        #expect(!denied.isBlocked)                                           // quiet by choice: nothing to say
    }

    @Test func turningTheSwitchOffClearsWhatWasScheduled() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        let now = morning(context)
        await reminders.replan(in: context, now: now)
        #expect(!(await client.pending()).isEmpty)
        reminders.remindersOnThisDevice = false
        await reminders.replan(in: context, now: now)
        #expect(await client.pending().isEmpty)
    }

    @Test func theMorningListCanBeSwitchedOffOnItsOwn() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        reminders.morningEnabled = false
        await reminders.replan(in: context, now: morning(context))
        let pending = await client.pending()
        #expect(pending.allSatisfy { !$0.id.hasPrefix("morning:") } && !pending.isEmpty)
    }

    @Test func aHabitsReminderGoesWhenItIsArchived() async throws {
        let context = try store()
        var draft = HabitDraft(kind: .binary)
        draft.title = "Water"
        draft.windows[0].reminderMinute = 18 * 60
        let habit = try HabitEditing.create(draft, in: context, now: morning(context).addingTimeInterval(-86_400 * 3))
        let (reminders, client) = center(.granted)
        let now = morning(context)
        await reminders.replan(in: context, now: now)
        #expect(await client.pending().contains { $0.id.hasPrefix("habit:") && $0.content.title == "Water" })
        habit.isArchived = true
        await reminders.replan(in: context, now: now)
        #expect(await client.pending().allSatisfy { !$0.id.hasPrefix("habit:") })
    }

    @Test func movingThePlanningTimeMovesThePrompts() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        let now = morning(context)
        await reminders.replan(in: context, now: now)
        let before = await client.pending().filter { $0.id.hasPrefix("planning:") }.sorted { $0.fireDate < $1.fireDate }
        try context.fetch(FetchDescriptor<UserSettings>()).first?.planningMinute = 21 * 60
        await reminders.replan(in: context, now: now)
        let after = await client.pending().filter { $0.id.hasPrefix("planning:") }.sorted { $0.fireDate < $1.fireDate }
        #expect(after.count == 5 && before.count == 5)
        #expect(zip(before, after).allSatisfy { abs($1.fireDate.timeIntervalSince($0.fireDate) - 3600) < 1 })   // 20:00 → 21:00
    }

    @Test func askingInContextTurnsANotAskedDeviceOn() async throws {
        let (reminders, _) = center(.notAsked)
        await reminders.refresh()
        #expect(reminders.permission == .notAsked && reminders.isBlocked)
        await reminders.requestPermission()
        #expect(reminders.permission == .granted && !reminders.isBlocked)
    }

    @Test func thePreferencesAreKeptOnThisDevice() {
        let d = defaults()
        let (first, _) = center(.granted, defaults: d)
        #expect(first.remindersOnThisDevice && first.morningEnabled && !first.dontRemind && first.bannerDismissedOn == nil)
        first.remindersOnThisDevice = false
        first.morningEnabled = false
        first.dontRemind = true
        first.dismissBanner(today: CalendarDate(year: 2026, month: 10, day: 15)!)
        let (second, _) = center(.granted, defaults: d)
        #expect(!second.remindersOnThisDevice && !second.morningEnabled && second.dontRemind)
        #expect(second.bannerDismissedOn == CalendarDate(year: 2026, month: 10, day: 15))
    }

    @Test func aTappedNotificationLeavesARouteForTheScreenToTake() {
        let (reminders, _) = center(.granted)
        #expect(reminders.route == nil)
        reminders.route = NotificationRoute.route(forID: "planning:2026-10-16")
        #expect(reminders.route == .planning(CalendarDate(year: 2026, month: 10, day: 16)!))
    }

    // MARK: Access

    private func storefront(_ context: ModelContext, firstLaunchDaysAgo days: Int, subscribed: Bool = false) async -> Storefront {
        try? context.fetch(FetchDescriptor<UserSettings>()).first?.firstLaunchAt = morning(context).addingTimeInterval(-Double(days) * 86_400)
        let store = Storefront(client: FakeStoreClient(active: subscribed), defaults: defaults(), accessOverride: nil)
        await store.refresh()
        return store
    }

    @Test func readOnlyStopsEverythingTheCentreWouldSchedule() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        reminders.storefront = await storefront(context, firstLaunchDaysAgo: 30)
        await reminders.replan(in: context, now: morning(context))
        #expect(await client.pending().isEmpty)
    }

    @Test func subscribingBringsThePlannerBackAtOnce() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        let store = await storefront(context, firstLaunchDaysAgo: 30)
        reminders.storefront = store
        await reminders.replan(in: context, now: morning(context))
        #expect(await client.pending().isEmpty)
        await store.purchase(.monthly)
        await reminders.replan(in: context, now: morning(context))
        #expect(!(await client.pending()).isEmpty)
    }

    @Test func theTrialAddsItsThreeQuietRemindersAtNineAndASubscriberHasNone() async throws {
        let context = try store()
        let (reminders, client) = center(.granted)
        reminders.storefront = await storefront(context, firstLaunchDaysAgo: 9)           // day 10 today: 12, 14 and 15 are ahead
        await reminders.replan(in: context, now: morning(context))
        let trial = await client.pending().filter { $0.id.hasPrefix("trial:") }
        #expect(Set(trial.map(\.id)) == ["trial:12", "trial:14", "trial:15"])
        #expect(trial.allSatisfy { Calendar.current.component(.hour, from: $0.fireDate) == 9 })

        let (other, otherClient) = center(.granted)
        other.storefront = await storefront(context, firstLaunchDaysAgo: 9, subscribed: true)
        await other.replan(in: context, now: morning(context))
        #expect(await otherClient.pending().allSatisfy { !$0.id.hasPrefix("trial:") })
    }
}
