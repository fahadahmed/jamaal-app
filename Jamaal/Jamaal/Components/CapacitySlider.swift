//
//  CapacitySlider.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// The three-step capacity slider: Low · Medium · High. A glass thumb on a hairline track that snaps to a
/// step; each label is also a tap target, and VoiceOver adjusts it like any slider.
struct CapacitySlider: View {
    @Environment(\.threads) private var threads
    let level: CapacityLevel
    /// Optional detail after each label ("LOW · 2H"), as on the Load step.
    var details: [CapacityLevel: String] = [:]
    let onChange: (CapacityLevel) -> Void

    private let thumb = CGSize(width: 46, height: 34)

    var body: some View {
        VStack(spacing: ThreadsSpace.tight) {
            GeometryReader { proxy in
                let travel = max(1, proxy.size.width - thumb.width)
                let x = CGFloat(TodayCopy.step(for: level)) / 2 * travel
                ZStack(alignment: .leading) {
                    Capsule().fill(threads.line).frame(height: 4).padding(.horizontal, thumb.width / 2)
                    ForEach(0..<3, id: \.self) { step in
                        Capsule().fill(threads.ink3).frame(width: 4, height: 12)
                            .offset(x: thumb.width / 2 - 2 + CGFloat(step) / 2 * travel)
                    }
                    Capsule()
                        .fill(threads.card)
                        .overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                        .threadsElevation(.lift, in: Capsule())
                        .frame(width: thumb.width, height: thumb.height)
                        .offset(x: x)
                }
                .frame(height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    let fraction = (drag.location.x - thumb.width / 2) / travel
                    select(TodayCopy.level(forStep: Int((fraction * 2).rounded())))
                })
            }
            .frame(height: ThreadsHit.minimum)

            HStack {
                ForEach(TodayCopy.levels, id: \.self) { item in
                    Button { select(item) } label: {
                        Text(details[item].map { "\(TodayCopy.label(for: item)) · \($0)" } ?? TodayCopy.label(for: item))
                            .threadsType(.label)
                            .foregroundStyle(item == level ? threads.ink : threads.ink3)
                            .frame(maxWidth: .infinity, minHeight: ThreadsHit.minimum)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                }
            }
        }
        .threadsAnimation(.state, value: level)
        // VoiceOver and UI tests meet it as an ordinary three-step slider.
        .accessibilityRepresentation {
            Slider(
                value: Binding(get: { Double(TodayCopy.step(for: level)) }, set: { select(TodayCopy.level(forStep: Int($0.rounded()))) }),
                in: 0...2, step: 1
            )
            .accessibilityLabel("Capacity for today")
            .accessibilityValue(TodayCopy.label(for: level).capitalized)
        }
    }

    private func select(_ new: CapacityLevel) {
        guard new != level else { return }
        onChange(new)
    }
}
