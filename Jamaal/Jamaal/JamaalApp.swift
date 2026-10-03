//
//  JamaalApp.swift
//  Jamaal
//
//  Created by Fahad Ahmed on 25/9/2026.
//

import SwiftData
import SwiftUI
import ThreadsTokens

@main
struct JamaalApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer?
    private let openError: Error?

    init() {
        // Fraunces, Hanken Grotesk and JetBrains Mono ship inside ThreadsKit; register them before the first view.
        let failures = ThreadsFonts.registerAll()
        assert(failures.isEmpty, "Fonts failed to register: \(failures)")

        do {
            container = try AppEngine.makeContainer()
            openError = nil
        } catch {
            container = nil
            openError = error
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    AppShell()
                        .modelContainer(container)
                        .onAppear { tick(container) }
                        .onChange(of: scenePhase) { _, phase in
                            if phase == .active { tick(container) }
                        }
                } else {
                    // A store that won't open must not crash the app (docs: Permissions and problems).
                    // The recovery screen (Try again / Reset this device's data) is its own change.
                    PlaceholderScreen(eyebrow: "Jamaal", title: "Couldn't open your data",
                                      note: openError.map { "\($0.localizedDescription)" } ?? "")
                }
            }
            .environment(\.threads, JamaalPalette())
        }
    }

    /// Keeps the data current on launch and whenever the app becomes active.
    @MainActor
    private func tick(_ container: ModelContainer) {
        do {
            try AppEngine.tick(context: container.mainContext)
        } catch {
            assertionFailure("Engine tick failed: \(error)")
        }
    }
}
