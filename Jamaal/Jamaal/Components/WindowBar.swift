//
//  WindowBar.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// An Anchor's window as a thin bar: empty while upcoming, filling as the window passes, terracotta when it is
/// closing soon, and full once closed. A quiet outline, not a gauge: nothing about it scolds.
struct WindowBar: View {
    @Environment(\.threads) private var threads
    let progress: Double
    let state: AnchorWindowState
    let isDecided: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(threads.line)
                if state == .upcoming && !isDecided {
                    Capsule().strokeBorder(threads.line2, lineWidth: 1)
                } else {
                    Capsule().fill(fill).frame(width: max(6, proxy.size.width * progress))
                }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        if isDecided { return threads.ink3.opacity(0.5) }
        return state == .closingSoon ? threads.terra : threads.deep
    }
}
