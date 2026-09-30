//
//  ContentView.swift
//  Jamaal
//
//  Created by Fahad Ahmed on 25/9/2026.
//

import SwiftUI
import ThreadsTokens

/// Placeholder root view. It exists to prove the app links ThreadsKit; the
/// real Today screen replaces it.
struct ContentView: View {
    var body: some View {
        Text("Jamaal")
            .foregroundStyle(Color.Threads.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Threads.app)
    }
}

#Preview {
    ContentView()
}
