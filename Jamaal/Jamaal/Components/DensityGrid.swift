//
//  DensityGrid.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// A habit's days as small squares, oldest first, in rows of 14: filled by how much was done, a miss in its own
/// quiet colour (never an error red), and unscheduled, paused, future and still-open days left pale. A grid, not a
/// streak: nothing here counts in a row.
struct DensityGrid: View {
    @Environment(\.threads) private var threads
    let cells: [DensityCell]
    var columns = 14
    /// Tapping a day, when it can be corrected.
    var onTap: ((DensityCell) -> Void)?
    var isTappable: (DensityCell) -> Bool = { _ in false }

    private let spacing: CGFloat = 5

    var body: some View {
        let layout = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        LazyVGrid(columns: layout, spacing: spacing) {
            ForEach(cells, id: \.day) { cell in
                let square = RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color(cell.state)).aspectRatio(1, contentMode: .fit)
                if let onTap, isTappable(cell) {
                    Button { onTap(cell) } label: { square.overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(threads.ink3.opacity(0.35), lineWidth: 0.5)) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Day \(cell.day.day), \(word(cell.state))")
                        .accessibilityHint("Correct this day")
                } else {
                    square.accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func color(_ state: DensityState) -> Color {
        switch state {
        case .complete: threads.d1
        case .partialHigh: threads.d2
        case .partialLow: threads.d3
        case .missed: threads.missed
        case .empty: threads.line
        }
    }

    private func word(_ state: DensityState) -> String {
        switch state {
        case .complete: "done"
        case .partialHigh, .partialLow: "partly done"
        case .missed: "not done"
        case .empty: "nothing to show"
        }
    }
}
