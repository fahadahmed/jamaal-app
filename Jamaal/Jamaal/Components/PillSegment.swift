//
//  PillSegment.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The two-way switch at the top of the Habits tab (Habits | Anchors), as drawn in AN-01: a pill track on `line`, the
/// chosen option in a white `selected` pill with its title in semibold ink, the other in `ink2`.
struct PillSegment<Option: Hashable>: View {
    @Environment(\.threads) private var threads
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let identifier: (Option) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button { withAnimation(.snappy(duration: 0.2)) { selection = option } } label: {
                    Text(title(option))
                        .font(.custom(isOn ? "HankenGrotesk-SemiBold" : "HankenGrotesk-Regular", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(isOn ? threads.ink : threads.ink2)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background { if isOn { Capsule().fill(threads.selected) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier(identifier(option))
            }
        }
        .padding(3)
        .background(Capsule().fill(threads.line))
        .accessibilityElement(children: .contain)
    }
}

/// The round glass Add button beside it (44 pt, as drawn).
struct AddCircleButton: View {
    @Environment(\.threads) private var threads
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus").font(.title3).foregroundStyle(threads.ink)
                .frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
