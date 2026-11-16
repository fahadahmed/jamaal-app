//
//  CollapsibleSection.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A section that folds to one line: its eyebrow, a short summary of what is inside, and a chevron. Used on Today so Anchors and Habits
/// take a line each until they are wanted, and the tasks sit near the top. The summary is what the section would say in a glance.
struct CollapsibleSection<Content: View>: View {
    @Environment(\.threads) private var threads
    let title: String
    let summary: String
    let identifier: String
    @Binding var isOpen: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Button { withAnimation(.snappy) { isOpen.toggle() } } label: {
                HStack(alignment: .firstTextBaseline, spacing: ThreadsSpace.tight) {
                    SectionLabel(title: title)
                    Spacer(minLength: ThreadsSpace.tight)
                    if !isOpen {
                        Text(summary).threadsType(.meta).foregroundStyle(threads.ink2).lineLimit(1).truncationMode(.tail)
                    }
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down").font(.footnote).foregroundStyle(threads.ink3)
                }
                .frame(minHeight: ThreadsHit.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(summary)")
            .accessibilityHint(TodayCopy.sectionHint(isOpen: isOpen))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
            if isOpen { content }
        }
    }
}
