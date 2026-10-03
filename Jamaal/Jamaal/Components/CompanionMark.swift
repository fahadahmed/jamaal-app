//
//  CompanionMark.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// Jamaal's mark beside a companion line: an italic "J" and a terracotta full stop on a `deep` disc.
struct CompanionMark: View {
    @Environment(\.threads) private var threads
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(threads.deep)
            .frame(width: size, height: size)
            .overlay {
                (Text("J").foregroundStyle(threads.onDeep) + Text(".").foregroundStyle(threads.terra))
                    .font(.custom(ThreadsType.displayItalicFontName, size: size * 0.5))
            }
            .accessibilityHidden(true)
    }
}
