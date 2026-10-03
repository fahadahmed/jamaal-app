//
//  ContentView.swift
//  Jamaal
//
//  Created by Fahad Ahmed on 25/9/2026.
//

import SwiftUI
import ThreadsTokens

/// Placeholder root view. It exists to prove the app links ThreadsKit (palette from the environment,
/// a type role); the real shell and Today screen replace it.
struct ContentView: View {
    @Environment(\.threads) private var threads

    var body: some View {
        Text("Jamaal")
            .threadsType(.display(.large))
            .foregroundStyle(threads.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(threads.app)
    }
}

#Preview {
    ContentView()
}
