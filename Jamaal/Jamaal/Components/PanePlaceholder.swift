//
//  PanePlaceholder.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// What a detail pane says while nothing is picked in the list beside it (Habits, Anchors).
struct PanePlaceholder: View {
    @Environment(\.threads) private var threads
    let text: String
    let identifier: String

    var body: some View {
        VStack {
            Spacer()
            Text(text).threadsType(.lede).foregroundStyle(threads.ink2).accessibilityIdentifier(identifier)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(threads.app.ignoresSafeArea())
    }
}

extension View {
    /// A list row that is open in the pane beside the list: a white card with an ink outline, drawn into the margin so the
    /// row's content doesn't move (as Today's selected task).
    func paneSelected(_ isSelected: Bool) -> some View {
        modifier(PaneSelectedRow(isSelected: isSelected))
    }
}

private struct PaneSelectedRow: ViewModifier {
    @Environment(\.threads) private var threads
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: ThreadsRadius.card)
                        .fill(threads.card)
                        .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(threads.ink, lineWidth: 1.5))
                        .padding(.horizontal, -ThreadsSpace.row)
                        .padding(.vertical, -2)
                }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: In a pane

private struct IsInPaneKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// True for a screen shown in the pane beside a list (regular width) rather than pushed: it has no back button.
    var isInPane: Bool {
        get { self[IsInPaneKey.self] }
        set { self[IsInPaneKey.self] = newValue }
    }
}
