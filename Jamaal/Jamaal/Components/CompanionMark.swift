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

/// The mark beside a companion line, which stacks above it at accessibility text sizes: beside a line set that large
/// a long word ("tomorrow.") needs more width than is left, and widens the whole column.
struct CompanionRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder let content: Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: ThreadsSpace.row))
            : AnyLayout(HStackLayout(alignment: .top, spacing: ThreadsSpace.row))
        layout {
            CompanionMark()
            content
        }
    }
}
