//
//  WellbeingScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Wellbeing (WB-01 … WB-03): a score derived only from what was done, in plain words; or, until seven active days
/// exist, what it will read. One calm card at most, with one change and *Not now*.
struct WellbeingScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    // Observed so the read refreshes when a day is finalised or a plan changes, here or on another device.
    @Query private var plans: [DayPlan]
    @Query private var nudges: [NudgeLog]
    @State private var now = Date.now
    @State private var outcome: String?
    @State private var opening: Habit?

    var body: some View {
        let _ = (plans.map { [$0.completionRate, $0.wasOverloaded ? 1 : 0, Double($0.completionBasis)] }, nudges.map { [$0.subjectKey ?? "", $0.dismissedAt == nil ? "0" : "1"] })
        let boundary = TodayDay.boundary(in: context)
        let snapshot = try? Wellbeing.snapshot(now: now, boundary: boundary, firstWeekday: Calendar.current.firstWeekday, context: context)
        let patterns = (try? Wellbeing.patterns(now: now, boundary: boundary, firstWeekday: Calendar.current.firstWeekday, context: context)) ?? []
        let nudge = try? Wellbeing.currentNudge(patterns: patterns, now: now, boundary: boundary, nudgesEnabled: true, context: context)
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                Text("Wellbeing").threadsType(.display(.large)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                if let snapshot {
                    switch snapshot.state {
                    case .gathering(let days, let needed): gathering(days, needed)
                    case .active(let score, let trend): active(snapshot, score: score, trend: trend, patterns: patterns, nudge: nudge ?? nil, boundary: boundary)
                    }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.row).padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(threads.app)
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .sheet(item: $opening) { habit in
            NavigationStack { HabitDetailScreen(habit: habit) }
        }
    }

    // MARK: Gathering data (WB-03)

    private func gathering(_ days: Int, _ needed: Int) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            HStack(spacing: 6) {
                ForEach(0..<needed, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4).fill(index < days ? threads.deep : threads.line2).frame(width: 36, height: 36)
                }
                Text(WellbeingCopy.gathering(activeDays: days, needed: needed)).threadsType(.lede).foregroundStyle(threads.ink2)
                    .padding(.leading, ThreadsSpace.tight)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(WellbeingCopy.gathering(activeDays: days, needed: needed))
            .accessibilityIdentifier("gatheringCount")
            Text(WellbeingCopy.gatheringLine).threadsType(.display(.compact)).foregroundStyle(threads.ink2)
            VStack(alignment: .leading, spacing: 0) {
                Divider().overlay(threads.line)
                Text("WHAT IT WILL READ").threadsType(.label).foregroundStyle(threads.ink2).padding(.vertical, ThreadsSpace.row)
                ForEach(WellbeingCopy.willRead, id: \.title) { item in
                    HStack {
                        Text(item.title).threadsType(.lede).foregroundStyle(threads.ink)
                        Spacer()
                        Text(item.source).threadsType(.body).foregroundStyle(threads.ink2)
                    }
                    .frame(minHeight: 52)
                    .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
                }
            }
            Text(WellbeingCopy.nothingToFillIn).threadsType(.body).foregroundStyle(threads.ink2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wellbeingGathering")
    }

    // MARK: A reading (WB-01, WB-02)

    private func active(_ snapshot: WellbeingSnapshot, score: Int, trend: WellbeingTrend?, patterns: [WellbeingPattern],
                        nudge: WellbeingNudge?, boundary: DayBoundary) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            HStack(alignment: .center, spacing: ThreadsSpace.row) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    ThreadsNumeral("\(score)", size: .large).foregroundStyle(threads.ink)
                        .accessibilityLabel("\(score)").accessibilityIdentifier("wellbeingScore")
                    if let line = WellbeingCopy.trend(trend) {
                        Text(line).threadsType(.body).foregroundStyle(threads.ink2).accessibilityIdentifier("wellbeingTrend")
                    }
                }
                Spacer(minLength: ThreadsSpace.tight)
                Sparkline(points: snapshot.sparkline).frame(width: 150, height: 44)
            }
            Text(WellbeingCopy.read(snapshot, patterns: patterns)).threadsType(.lede).foregroundStyle(threads.ink)
                .accessibilityIdentifier("wellbeingRead")
            if let nudge { card(nudge, boundary: boundary) } else if let outcome {
                Text(outcome).threadsType(.lede).foregroundStyle(threads.ink2).accessibilityIdentifier("wellbeingOutcome")
            }
            VStack(spacing: 0) {
                Divider().overlay(threads.line)
                ForEach(WellbeingCopy.rows(snapshot), id: \.id) { row in
                    HStack {
                        Text(row.title).threadsType(.lede).foregroundStyle(threads.ink2)
                        Spacer()
                        Text(row.value).threadsType(.lede).foregroundStyle(threads.ink)
                    }
                    .frame(minHeight: 56)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("wellbeingRow-\(row.id)")
                    Divider().overlay(threads.line)
                }
            }
            Text("LAST \(snapshot.activeDays) ACTIVE DAYS").threadsType(.label).foregroundStyle(threads.ink2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wellbeingActive")
        .task(id: nudge?.pattern.subjectKey) {
            if let nudge { try? Wellbeing.markShown(nudge, now: now, boundary: boundary, context: context) }
        }
    }

    private func card(_ nudge: WellbeingNudge, boundary: DayBoundary) -> some View {
        WellbeingCard(nudge: nudge, onAction: { take(nudge, boundary: boundary) }, onNotNow: {
            try? Wellbeing.dismiss(nudge, now: now, boundary: boundary, context: context)
        })
    }

    private func take(_ nudge: WellbeingNudge, boundary: DayBoundary) {
        guard let result = try? Wellbeing.apply(nudge, now: now, boundary: boundary, context: context) else { return }
        if case .openHabit(let habit) = result { opening = habit } else { outcome = WellbeingCopy.outcome(result) }
    }
}

/// The one inline card: a pattern and one change, with *Not now*. Shared by the Wellbeing tab and Today.
struct WellbeingCard: View {
    @Environment(\.threads) private var threads
    let nudge: WellbeingNudge
    let onAction: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            HStack(alignment: .top, spacing: ThreadsSpace.row) {
                CompanionMark()
                Text(WellbeingCopy.cardText(nudge.pattern)).threadsType(.lede).foregroundStyle(threads.ink)
            }
            HStack(spacing: ThreadsSpace.tight) {
                Button(action: onAction) {
                    Text(WellbeingCopy.cardAction(nudge.pattern)).threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52).background(Capsule().fill(threads.terra)).contentShape(Capsule())
                }
                .accessibilityIdentifier("wellbeingAction")
                PillButton(title: "Not now", fills: true, action: onNotNow).accessibilityIdentifier("wellbeingNotNow")
            }
            .buttonStyle(.plain)
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(threads.line2, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wellbeingCard")
    }
}
