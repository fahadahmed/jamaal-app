//
//  NotificationClient.swift
//  Jamaal
//

import Foundation
import UserNotifications
import JamaalCore

/// The system's notification centre, behind a seam so the schedule can be tested and driven in UI tests.
@MainActor
protocol NotificationClient {
    func permission() async -> NotificationPermission
    /// Shows the system prompt (only when it hasn't been shown) and returns whether it was granted.
    func requestPermission() async -> Bool
    func pending() async -> [PendingNotification]
    func apply(add: [PlannedNotification], remove: [String]) async
}

@MainActor
struct SystemNotificationClient: NotificationClient {
    private var center: UNUserNotificationCenter { .current() }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notAsked
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default: .denied
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func pending() async -> [PendingNotification] {
        await center.pendingNotificationRequests().compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger, let fire = trigger.nextTriggerDate() else { return nil }
            return PendingNotification(id: request.identifier, fireDate: fire, content: NotificationContent(title: request.content.title, body: request.content.body))
        }
    }

    func apply(add: [PlannedNotification], remove: [String]) async {
        if !remove.isEmpty { center.removePendingNotificationRequests(withIdentifiers: remove) }
        for item in add {
            let words = NotificationMessages.content(for: item.kind)
            let content = UNMutableNotificationContent()
            content.title = words.title
            content.body = words.body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }
}

#if DEBUG
/// `-JamaalFakeNotifications granted | denied | notAsked`: the permission without the system prompt, and a schedule
/// that lives in memory, so UI tests don't depend on the simulator's notification settings.
@MainActor
final class FakeNotificationClient: NotificationClient {
    private var state: NotificationPermission
    private var scheduled: [String: PendingNotification] = [:]

    init(state: NotificationPermission) { self.state = state }

    func permission() async -> NotificationPermission { state }
    func requestPermission() async -> Bool {
        if state == .notAsked { state = .granted }
        return state == .granted
    }
    func pending() async -> [PendingNotification] { Array(scheduled.values) }
    func apply(add: [PlannedNotification], remove: [String]) async {
        for id in remove { scheduled[id] = nil }
        for item in add { scheduled[item.id] = PendingNotification(id: item.id, fireDate: item.fireDate, content: NotificationMessages.content(for: item.kind)) }
    }

    static func fromLaunchArguments() -> FakeNotificationClient? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-JamaalFakeNotifications"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "granted": return FakeNotificationClient(state: .granted)
        case "denied": return FakeNotificationClient(state: .denied)
        default: return FakeNotificationClient(state: .notAsked)
        }
    }
}
#endif

/// Taps and foreground delivery. A reminder that arrives while the app is open still shows, quietly.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    var onRoute: (@MainActor (NotificationRoute) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let route = NotificationRoute.route(forID: response.notification.request.identifier)
        await MainActor.run { onRoute?(route) }
    }
}
