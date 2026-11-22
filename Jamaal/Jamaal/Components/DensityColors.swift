//
//  DensityColors.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// Which step of the density ramp a habit day is drawn in. The ramp is **light, mid, full** (`d1`, `d2`, `d3`): the more of a day was done, the
/// fuller its square, so a run of completed days reads as a run of strong squares. A missed day has its own quiet colour (never an error
/// red) and an empty one (not scheduled, paused, before the habit existed, or still open) stays a pale line.
enum DensityColors {
    enum Step: Equatable {
        case empty, missed, light, mid, full

        /// How strongly the step reads, for the one rule that matters: more done is never lighter.
        var weight: Int {
            switch self {
            case .empty: 0
            case .missed: 0
            case .light: 1
            case .mid: 2
            case .full: 3
            }
        }
    }

    static func step(for state: DensityState) -> Step {
        switch state {
        case .complete: .full
        case .partialHigh: .mid
        case .partialLow: .light
        case .missed: .missed
        case .empty: .empty
        }
    }

    static func color(for step: Step, in threads: any ThreadsPalette) -> Color {
        switch step {
        case .full: threads.d3
        case .mid: threads.d2
        case .light: threads.d1
        case .missed: threads.missed
        case .empty: threads.line
        }
    }

    static func color(for state: DensityState, in threads: any ThreadsPalette) -> Color {
        color(for: step(for: state), in: threads)
    }
}
