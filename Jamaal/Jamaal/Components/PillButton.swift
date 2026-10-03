//
//  PillButton.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A quiet outlined pill: "Held today", "Slip". `dashed` is the softer treatment for an action that records
/// something you'd rather not have happened.
struct PillButton: View {
    @Environment(\.threads) private var threads
    let title: String
    var dashed = false
    /// Fills the width it is given (a row of equal buttons) instead of hugging its title.
    var fills = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .threadsType(.row)
                .foregroundStyle(threads.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(fills ? EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8) : ThreadsSpace.pillButtonPadding)
                .frame(maxWidth: fills ? .infinity : nil, minHeight: ThreadsHit.minimum)
                .background(Capsule().fill(threads.card.opacity(0.6)))
                .overlay(Capsule().strokeBorder(threads.line2, style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : [])))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The counted habit's − | + capsule.
struct StepperPill: View {
    @Environment(\.threads) private var threads
    let title: String
    let canDecrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onDecrement) { Image(systemName: "minus").frame(width: 54, height: ThreadsHit.minimum) }
                .disabled(!canDecrement)
                .opacity(canDecrement ? 1 : 0.35)
                .accessibilityLabel("Take one from \(title)")
            Rectangle().fill(threads.line2).frame(width: 1, height: 22)
            Button(action: onIncrement) { Image(systemName: "plus").frame(width: 54, height: ThreadsHit.minimum) }
                .accessibilityLabel("Add one to \(title)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(threads.ink)
        .background(Capsule().fill(threads.card.opacity(0.6)))
        .overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
    }
}
