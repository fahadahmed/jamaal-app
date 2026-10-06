//
//  ReminderCenter.swift
//  Jamaal
//

import Foundation
import Observation
import SwiftData
import JamaalCore
#if canImport(UIKit)
import UIKit
#endif

/// This device's reminders: the permission (read on launch and every foreground), the per-device switch, the schedule
/// (planned by `NotificationPlanner`, diffed and applied), and where a tapped notification leads.
@MainActor
@Observable
final class ReminderCenter {
    private(set) var permission: NotificationPermission = .notAsked
    private(set) var scheduledCount = 0
    /// Where a tapped notification wants to go; the screen that handles it clears it.
    var route: NotificationRoute?

    /// "Send reminders on this device": local, on for iPhone, off for iPad and Mac.
    var remindersOnThisDevice: Bool { didSet { defaults.set(remindersOnThisDevice, forKey: Keys.switchOn) } }
    /// The optional morning list.
    var morningEnabled: Bool { didSet { defaults.set(morningEnabled, forKey: Keys.morning) } }
    /// The Today banner was dismissed on this logical day.
    var bannerDismissedOn: CalendarDate? {
        didSet { defaults.set(bannerDismissedOn?.isoString, forKey: Keys.dismissedOn) }
    }
    /// "Don't remind me": no banner, ever (local).
    var dontRemind: Bool { didSet { defaults.set(dontRemind, forKey: Keys.dontRemind) } }

    /// Where access comes from; planning follows it (read-only stops the schedule, the trial adds its reminders).
    var storefront: Storefront?
    private let client: any NotificationClient
    private let defaults: UserDefaults
    private var busy = false
    private var again = false
    private var debounce: Task<Void, Never>?

    private enum Keys {
        static let switchOn = "remindersOnThisDevice", morning = "morningListOn", dismissedOn = "reminderBannerDismissedOn", dontRemind = "reminderBannerDontRemind"
    }

    init(client: (any NotificationClient)? = nil, defaults: UserDefaults? = nil, isPhone: Bool? = nil) {
        #if DEBUG
        self.client = client ?? FakeNotificationClient.fromLaunchArguments() ?? SystemNotificationClient()
        #else
        self.client = client ?? SystemNotificationClient()
        #endif
        self.defaults = defaults ?? Self.standardDefaults
        let defaults = self.defaults
        remindersOnThisDevice = defaults.object(forKey: Keys.switchOn) as? Bool ?? isPhone ?? Self.deviceIsPhone
        morningEnabled = defaults.object(forKey: Keys.morning) as? Bool ?? true
        bannerDismissedOn = defaults.string(forKey: Keys.dismissedOn).flatMap(CalendarDate.init(isoString:))
        dontRemind = defaults.bool(forKey: Keys.dontRemind)
    }

    /// The device's own preferences; in the in-memory test mode a fresh set each launch, so tests don't leak into each other.
    private static var standardDefaults: UserDefaults {
        #if DEBUG
        if DebugLaunch.inMemory, let suite = UserDefaults(suiteName: "JamaalInMemoryTests") {
            suite.removePersistentDomain(forName: "JamaalInMemoryTests")
            return suite
        }
        #endif
        return .standard
    }

    static var deviceIsPhone: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    /// "iPhone", "iPad" or "Mac": for "Send reminders on this iPhone".
    static var deviceName: String {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
        "Mac"
        #endif
    }

    /// Whether reminders are wanted on this device but can't arrive: the switch is on and the permission isn't.
    var isBlocked: Bool { remindersOnThisDevice && permission != .granted }

    func refresh() async { permission = await client.permission() }

    /// Shows the system prompt, in context, then re-reads the permission.
    func requestPermission() async {
        _ = await client.requestPermission()
        await refresh()
    }

    func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        #endif
    }

    /// Plans from the current data and changes only what differs from what is pending. Calls arriving while one is
    /// running are folded into one more pass.
    func replan(in context: ModelContext, now: Date = .now) async {
        if busy { again = true; return }
        busy = true
        defer { busy = false }
        repeat {
            again = false
            await refresh()
            let inputs = PlannerInputs(
                now: now, boundary: TodayDay.boundary(in: context),
                access: storefront?.access(in: context, now: now) ?? .subscribed,
                trialStart: storefront?.trialStart(settings: try? context.fetch(FetchDescriptor<UserSettings>()).min { $0.createdAt < $1.createdAt },
                                                   boundary: TodayDay.boundary(in: context)),
                permissionGranted: permission == .granted, remindersOnThisDevice: remindersOnThisDevice, morningNudgeEnabled: morningEnabled)
            guard let planned = try? NotificationPlanner.plan(inputs, context: context) else { return }
            let changes = NotificationDiff.make(planned: planned, pending: await client.pending())
            await client.apply(add: changes.add, remove: changes.remove)
            scheduledCount = planned.count
        } while again
    }

    /// Replans shortly after a burst of changes (a save, a switch), so one edit doesn't trigger many passes.
    func scheduleReplan(in context: ModelContext) {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await self?.replan(in: context)
        }
    }

    func dismissBanner(today: CalendarDate) { bannerDismissedOn = today }
}
