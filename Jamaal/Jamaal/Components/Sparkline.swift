//
//  Sparkline.swift
//  Jamaal
//

import Charts
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The score over recent days as one quiet line: no axes, no colours that judge. Days without a reading leave a gap.
struct Sparkline: View {
    @Environment(\.threads) private var threads
    @Environment(\.colorScheme) private var colorScheme
    let points: [SparkPoint]

    /// The deep teal reads on the light page, but on the dark one it is blue on blue, so Dark mode draws the line in the light ink.
    private var line: Color { colorScheme == .dark ? threads.ink : threads.deep }

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                if let score = point.score {
                    LineMark(x: .value("Day", index), y: .value("Score", score))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(line)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...100)
        .chartXScale(domain: 0...max(1, points.count - 1))
        .accessibilityHidden(true)
    }
}
