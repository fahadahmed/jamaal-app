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
                .fixedSize(horizontal: !fills, vertical: false)                 // a hugging pill keeps its title; its neighbour gives way
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
            Button {
                trace("minus", enabled: canDecrement)
                onDecrement()
            } label: {
                Image(systemName: "minus").frame(width: 54, height: ThreadsHit.minimum).contentShape(Rectangle())
            }
            .disabled(!canDecrement)
            .opacity(canDecrement ? 1 : 0.35)
            .accessibilityLabel("Take one from \(title)")
            Rectangle().fill(threads.line2).frame(width: 1, height: 22)
            Button {
                trace("plus", enabled: true)
                onIncrement()
            } label: {
                Image(systemName: "plus").frame(width: 54, height: ThreadsHit.minimum).contentShape(Rectangle())
            }
            .accessibilityLabel("Add one to \(title)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(threads.ink)
        .background(Capsule().fill(threads.card.opacity(0.6)))
        .overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1).allowsHitTesting(false))
    }

    /// Debug builds log each tap that reaches the button (Console, category "stepper"), to tell a tap that never arrives
    /// from one that arrives and changes nothing.
    private func trace(_ side: String, enabled: Bool) {
        #if DEBUG
        stepperLog.info("\(side, privacy: .public) tapped on \(title, privacy: .public), enabled=\(enabled)")
        #endif
    }
}

#if DEBUG
import os
private let stepperLog = Logger(subsystem: "dev.fhdamd.Jamaal", category: "stepper")
#endif
