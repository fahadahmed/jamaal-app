//
//  HabitsScreen.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore
import ThreadsTokens

/// The Habits tab (HB-01). At compact width a **Habits | Anchors** segment sits at the top; at regular
/// width Anchors is its own sidebar item and the segment is hidden.
struct HabitsScreen: View {
    private enum Segment: String, CaseIterable { case habits = "Habits", anchors = "Anchors" }

    @Environment(\.threads) private var threads
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.requireAccess) private var requireAccess
    @State private var addingHabit = false
    @State private var addingAnchor = false
    @State private var segment: Segment = {
        #if DEBUG
        return DebugLaunch.anchorRules ? .anchors : .habits
        #else
        return .habits
        #endif
    }()

    var body: some View {
        NavigationStack {
          VStack(spacing: 0) {
            let compact = AppNavigation.showsAnchorsSegment(sizeClass: sizeClass)
            if compact {
                // AN-01 / HB-01: the switch and Add share a row; the title is below them.
                HStack(alignment: .center) {
                    PillSegment(options: Segment.allCases, selection: $segment, title: { $0.rawValue }, identifier: { "segment-\($0.rawValue.lowercased())" })
                    Spacer()
                    if segment == .anchors {
                        AddCircleButton(label: "Add an Anchor rule", identifier: "addAnchorRule") { if requireAccess(.createAnchorRule) { addingAnchor = true } }
                    } else {
                        AddCircleButton(label: "Add a habit", identifier: "addHabit") { if requireAccess(.createHabit) { addingHabit = true } }
                    }
                }
                .padding(.horizontal, ThreadsSpace.gutter)
                .padding(.top, ThreadsSpace.tight)
                .zIndex(1)                                                // so the button's shadow isn't cut off by the list below
            }
            if compact, segment == .anchors {
                AnchorsRulesView(adding: $addingAnchor, showsAddButton: false)
            } else {
                HabitsOverviewView(addingHabit: $addingHabit, showsAddButton: !compact)
            }
          }
          .background(threads.app.ignoresSafeArea())          // the segment sits on the app ground, not the system's white
          .navigationDestination(for: Habit.self) { habit in HabitDetailScreen(habit: habit) }
          .navigationDestination(for: AnchorRule.self) { rule in AnchorRuleDetailScreen(rule: rule) }
          .toolbar(.hidden, for: .navigationBar)
        }
    }
}
