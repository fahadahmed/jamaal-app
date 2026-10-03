//
//  CheckCircle.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The round tick on a task row: an empty ring, or a filled accent disc with a check when done.
struct CheckCircle: View {
    @Environment(\.threads) private var threads
    let isDone: Bool
    var isMuted = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isDone ? threads.accent : (isMuted ? threads.line2 : threads.ink3), lineWidth: 1.5)
                .background(Circle().fill(isDone ? threads.accent : .clear))
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(threads.onAccent)
            }
        }
        .frame(width: 28, height: 28)
        .frame(width: ThreadsHit.minimum, height: ThreadsHit.minimum)     // the tap target, not the drawing
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}
