//
//  DensityKey.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// The words of a heatmap's key (#424). A yes/no or avoid habit never has the two partial steps, so its key doesn't show them; a counted
/// or timed habit's does; a group's grid is about how many of its habits were done that day. The words are plain: a miss is "Not done",
/// never a failure, and the pale step says why it is pale.
enum DensityKeyCopy {
    enum Style: Equatable {
        case yesNo(HabitKind)
        case amount
        case group
    }

    struct Item: Equatable {
        var step: DensityColors.Step
        var word: String
    }

    static func style(for kind: HabitKind) -> Style {
        switch kind {
        case .counted, .timed: .amount
        case .avoid: .yesNo(.avoid)
        case .binary, .unknown: .yesNo(.binary)
        }
    }

    static func items(for style: Style) -> [Item] {
        switch style {
        case .yesNo(let kind):
            let avoid = kind == .avoid
            return [Item(step: .full, word: avoid ? "Held" : "Done"),
                    Item(step: .missed, word: avoid ? "Slipped" : "Not done"),
                    Item(step: .empty, word: "Nothing due")]
        case .amount:
            return [Item(step: .light, word: "Under half"), Item(step: .mid, word: "Half or more"), Item(step: .full, word: "Target reached"),
                    Item(step: .missed, word: "Not done"), Item(step: .empty, word: "Nothing due")]
        case .group:
            return [Item(step: .full, word: "Every habit"), Item(step: .mid, word: "Half or more"), Item(step: .light, word: "Under half"),
                    Item(step: .missed, word: "None"), Item(step: .empty, word: "Nothing due")]
        }
    }
}

/// A small swatch and a word for each colour a grid uses, under the grid. VoiceOver reads it as one line: the cells are decoration.
struct DensityKey: View {
    @Environment(\.threads) private var threads
    let style: DensityKeyCopy.Style
    /// The columns grow with the text size, so a word wraps rather than being cut off.
    @ScaledMetric(relativeTo: .caption) private var columnWidth: CGFloat = 104

    var body: some View {
        let items = DensityKeyCopy.items(for: style)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: ThreadsSpace.tight, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.word) { item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous).fill(DensityColors.color(for: item.step, in: threads))
                        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(threads.ink3.opacity(0.35), lineWidth: 0.5))
                        .frame(width: 12, height: 12)
                    Text(item.word).threadsType(.meta).foregroundStyle(threads.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key to the colours")
        .accessibilityValue(items.map(\.word).joined(separator: ", "))
        .accessibilityIdentifier("densityKey")
    }
}
