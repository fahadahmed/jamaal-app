//
//  PlaceholderScreen.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A calm stand-in for a screen that isn't built yet: an eyebrow, a display title and one line in `ink3`,
/// on `app`. It uses only ThreadsKit tokens, so the shell reads as the finished app will.
struct PlaceholderScreen: View {
    @Environment(\.threads) private var threads
    let eyebrow: String
    let title: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            Text(eyebrow)
                .threadsType(.label)
                .foregroundStyle(threads.ink3)
            Text(title)
                .threadsType(.display(.regular))
                .foregroundStyle(threads.ink)
            Text(note)
                .threadsType(.lede)
                .foregroundStyle(threads.ink3)
            Spacer()
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, ThreadsSpace.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(threads.app)
    }
}

#Preview {
    PlaceholderScreen(eyebrow: "Today", title: "Today", note: "Nothing here yet.")
}
