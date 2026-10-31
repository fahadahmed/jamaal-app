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
    @State private var selectedHabit: Habit?
    @State private var selectedRule: AnchorRule?
    @Environment(FoldMonitor.self) private var fold: FoldMonitor?
    @State private var columnsOriginX: CGFloat = 0
    @State private var segment: Segment = {
        #if DEBUG
        return DebugLaunch.anchorRules ? .anchors : .habits
        #else
        return .habits
        #endif
    }()

    private var compact: Bool { AppNavigation.showsAnchorsSegment(sizeClass: sizeClass) }

    var body: some View {
        if compact && AppNavigation.isRegular(sizeClass) { segmentPanes } else if compact { compactBody } else { widePanes }
    }

    /// An iPhone held wide (an iPhone Duo's inner display, landscape or half open): the Habits | Anchors switch stays above the list, and
    /// the picked habit or Anchor rule opens beside it instead of pushing (the shell reports regular width only from 700 pt, `PaneLayout`).
    private var segmentPanes: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                switchRow
                if segment == .anchors {
                    AnchorsRulesView(adding: $addingAnchor, showsAddButton: false, selected: selectedRule) { selectedRule = $0 }
                } else {
                    HabitsOverviewView(addingHabit: $addingHabit, showsAddButton: false, selected: selectedHabit) { selectedHabit = $0 }
                }
            }
            .frame(width: creaseListWidth ?? 380)                           // half open: the list fills its half and the pane starts at the crease
            Divider()
            Group {
                if segment == .anchors {
                    if let rule = selectedRule, !rule.isArchived {
                        AnchorRuleDetailScreen(rule: rule, embedded: true, onClose: { selectedRule = nil }).id(rule.id)
                    } else {
                        PanePlaceholder(text: "Pick an Anchor rule to see it here.", identifier: "anchorPlaceholder")
                    }
                } else if let habit = selectedHabit, !habit.isArchived {
                    HabitDetailScreen(habit: habit, embedded: true, onClose: { selectedHabit = nil }).id(habit.id)
                } else {
                    PanePlaceholder(text: "Pick a habit to see it here.", identifier: "habitPlaceholder")
                }
            }
            .frame(minWidth: 320, maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(segment == .anchors ? "anchorPane" : "habitPane")
        }
        .background(threads.app.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: { columnsOriginX = $0 }
    }

    private var creaseListWidth: CGFloat? {
        guard let crease = fold?.creaseX else { return nil }
        let width = FoldLayout.listWidth(creaseX: crease, listOriginX: columnsOriginX, fallback: 0)
        return width > 0 ? width : nil
    }

    /// AN-01 / HB-01: the switch and Add share a row; the title is below them.
    private var switchRow: some View {
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
        .zIndex(1)                                                        // so the button's shadow isn't cut off by the list below
    }

    /// Regular width (iPad, Mac): the habits on the left, the picked habit's detail beside them (iPad-HB-02).
    private var widePanes: some View {
        HStack(spacing: 0) {
            HabitsOverviewView(addingHabit: $addingHabit, showsAddButton: true, selected: selectedHabit) { selectedHabit = $0 }
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 380)
            Divider()
            Group {
                if let habit = selectedHabit, !habit.isArchived {
                    HabitDetailScreen(habit: habit, embedded: true, onClose: { selectedHabit = nil }).id(habit.id)
                } else {
                    PanePlaceholder(text: "Pick a habit to see it here.", identifier: "habitPlaceholder")
                }
            }
            .frame(minWidth: 320, maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("habitPane")
        }
        .background(threads.app.ignoresSafeArea())
    }

    private var compactBody: some View {
        NavigationStack {
          VStack(spacing: 0) {
            if compact { switchRow }
            if compact, segment == .anchors {
                AnchorsRulesView(adding: $addingAnchor, showsAddButton: false)
            } else {
                HabitsOverviewView(addingHabit: $addingHabit, showsAddButton: !compact)
            }
          }
          .background(threads.app.ignoresSafeArea())          // the segment sits on the app ground, not the system's white
          .navigationDestination(for: Habit.self) { habit in HabitDetailScreen(habit: habit) }
          .navigationDestination(for: AnchorRule.self) { rule in AnchorRuleDetailScreen(rule: rule) }
          .hidesNavigationBar()
        }
    }
}
