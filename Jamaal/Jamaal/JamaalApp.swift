//
//  JamaalApp.swift
//  Jamaal
//
//  Created by Fahad Ahmed on 25/9/2026.
//

import SwiftUI
import ThreadsTokens

@main
struct JamaalApp: App {
    init() {
        // Fraunces, Hanken Grotesk and JetBrains Mono ship inside ThreadsKit; register them before the first view.
        let failures = ThreadsFonts.registerAll()
        assert(failures.isEmpty, "Fonts failed to register: \(failures)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.threads, JamaalPalette())
        }
    }
}
