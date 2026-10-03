//
//  HabitsScreen.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The Habits tab (HB-01). At compact width a **Habits | Anchors** segment sits at the top; at regular
/// width Anchors is its own sidebar item and the segment is hidden.
struct HabitsScreen: View {
    private enum Segment: String, CaseIterable { case habits = "Habits", anchors = "Anchors" }

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var segment: Segment = .habits

    var body: some View {
        VStack(spacing: 0) {
            if AppNavigation.showsAnchorsSegment(sizeClass: sizeClass) {
                Picker("Habits or Anchors", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, ThreadsSpace.gutter)
                .padding(.top, ThreadsSpace.tight)
            }
            if AppNavigation.showsAnchorsSegment(sizeClass: sizeClass), segment == .anchors {
                AnchorsScreen()
            } else {
                PlaceholderScreen(eyebrow: "Habits", title: "Habits", note: "No habits yet — they'll appear as patterns do.")
            }
        }
    }
}
