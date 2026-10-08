//
//  DayShapeBar.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The working day as one bar (the wide Build step, NP-07): busy time dark, the rest light, the longest free gap outlined,
/// and the hours marked beneath. A picture of what the lines below say, so it reads as decoration to VoiceOver.
struct DayShapeBar: View {
    @Environment(\.threads) private var threads
    /// The working day, in minutes from midnight.
    let startMinute: Int
    let endMinute: Int
    /// Fixed commitments and the longest free gap, in minutes from midnight (clipped to the day).
    let busy: [Range<Int>]
    let longestGap: Range<Int>?

    private var span: CGFloat { CGFloat(max(endMinute - startMinute, 1)) }

    private func x(_ minute: Int, in width: CGFloat) -> CGFloat {
        CGFloat(min(max(minute, startMinute), endMinute) - startMinute) / span * width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(threads.d1)
                    ForEach(Array(busy.enumerated()), id: \.offset) { _, block in
                        let left = x(block.lowerBound, in: width), right = x(block.upperBound, in: width)
                        Rectangle().fill(threads.deep).frame(width: max(right - left, 3)).offset(x: left)
                    }
                    if let gap = longestGap {
                        let left = x(gap.lowerBound, in: width), right = x(gap.upperBound, in: width)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(threads.deep, lineWidth: 2)
                            .frame(width: max(right - left, 6))
                            .offset(x: left)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .frame(height: 30)
            GeometryReader { geo in
                ForEach(hours, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).threadsType(.label).foregroundStyle(threads.ink2)
                        .fixedSize()
                        .offset(x: x(hour * 60, in: geo.size.width))
                }
            }
            .frame(height: 16)
        }
        .accessibilityHidden(true)
    }

    /// Every second hour inside the day: 08, 10, 12 …
    private var hours: [Int] {
        let first = (startMinute + 119) / 120 * 2
        return Array(stride(from: first, through: endMinute / 60, by: 2))
    }
}
