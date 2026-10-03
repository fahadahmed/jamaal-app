//
//  SectionLabel.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A section's eyebrow: a short terracotta rule and the name in the label face ("— TASKS").
struct SectionLabel: View {
    @Environment(\.threads) private var threads
    let title: String

    var body: some View {
        HStack(spacing: ThreadsSpace.tight) {
            Rectangle().fill(threads.terra).frame(width: 22, height: 1)
            Text(title).threadsType(.label).foregroundStyle(threads.ink2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The display headline: a plain first line and an italic accent second line ("Four things, / gently paced.").
struct DisplayHeadline: View {
    @Environment(\.threads) private var threads
    let first: String
    let second: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(first).threadsType(.display(.large)).foregroundStyle(threads.ink)
            Text(second)
                .font(.custom(ThreadsType.displayItalicFontName, size: 38, relativeTo: .largeTitle))
                .foregroundStyle(threads.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
