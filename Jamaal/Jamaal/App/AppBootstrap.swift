//
//  AppBootstrap.swift
//  Jamaal
//

import SwiftData
import ThreadsTokens
import UserNotifications

/// Start-up work that must happen once per process. SwiftUI may build the `App` value more than once per launch, and each
/// build used to register the fonts again (the system logs "already registered" every time) and open another model
/// container on the same store. A `static let` runs once, however many times it is asked for.
enum AppBootstrap {
    /// The bundled fonts, registered once. Empty when all of them registered.
    static let fonts: [ThreadsFonts.Failure] = ThreadsFonts.registerAll()

    /// The first model container, or nil when the store won't open (the recovery screen takes over from there).
    @MainActor
    static let firstContainer: ModelContainer? = try? AppEngine.makeContainer()

    /// The one notification delegate: if each `App` value made its own, the one the system calls back could be a different
    /// object from the one the view tree gave its route handler to, and a tapped notification would go nowhere.
    @MainActor
    static let notificationDelegate: NotificationDelegate = {
        let delegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = delegate
        return delegate
    }()
}
