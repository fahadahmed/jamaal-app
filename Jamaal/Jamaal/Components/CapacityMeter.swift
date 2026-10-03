//
//  CapacityMeter.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// "2h 15m of 3h" with the load word on the right, over a bar. The bar is `deep`; an over-full day turns
/// it terracotta. A day past full still fills the bar and never blocks anything.
struct CapacityMeter: View {
    @Environment(\.threads) private var threads
    let plannedMinutes: Int
    let budgetMinutes: Int
    let state: LoadState
    let loadScore: Int
    /// Filtering Tasks never changes the load: the meter says it is still the whole day.
    var wholeDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            HStack {
                Text(TodayCopy.meter(plannedMinutes: plannedMinutes, budgetMinutes: budgetMinutes, wholeDay: wholeDay))
                    .threadsType(.body).foregroundStyle(threads.ink)
                Spacer()
                Text(TodayCopy.stateWord(state))
                    .threadsType(.label)
                    .foregroundStyle(TodayCopy.isOver(state) ? threads.terra : threads.ink2)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(threads.line)
                    Capsule()
                        .fill(TodayCopy.isOver(state) ? threads.terra : threads.deep)
                        .frame(width: proxy.size.width * min(1, CGFloat(loadScore) / 100))
                }
            }
            .frame(height: 8)
            .threadsAnimation(.state, value: loadScore)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's load")
        .accessibilityValue("\(TodayCopy.meter(plannedMinutes: plannedMinutes, budgetMinutes: budgetMinutes, wholeDay: wholeDay)), \(TodayCopy.stateWord(state).lowercased())")
    }
}
