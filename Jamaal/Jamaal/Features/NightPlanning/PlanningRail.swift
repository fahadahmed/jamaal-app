//
//  PlanningRail.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// The wide canvas's step rail (NP-07): the five steps down the left, each done (a check), current (a white card and a
/// terra ring) or still to come, with a one-line summary for the ones behind and the one open, and *Skip tonight* at the
/// bottom. A step that is done can be tapped to go back to it; the ones ahead are reached with Continue.
struct PlanningRail: View {
    @Environment(\.threads) private var threads
    let flow: PlanningFlow
    /// Bumped after any change, so the summaries are read again (the engine isn't observable).
    let revision: Int
    let onGo: (PlanningStep) -> Void
    let onSkip: () -> Void

    private enum Status { case done, current, upcoming }

    private func status(_ step: PlanningStep) -> Status {
        guard let index = flow.steps.firstIndex(of: step) else { return .upcoming }
        let current = flow.position - 1
        return index < current ? .done : (index == current ? .current : .upcoming)
    }

    var body: some View {
        let _ = revision
        VStack(alignment: .leading, spacing: 0) {
            Text(PlanningCopy.railEyebrow(for: flow.forDate, mode: flow.mode))
                .threadsType(.label).foregroundStyle(threads.ink2)
                .padding(.horizontal, ThreadsSpace.row).padding(.bottom, ThreadsSpace.row)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: ThreadsSpace.hair) {
                ForEach(flow.steps, id: \.self) { step in row(step) }
            }
            Spacer(minLength: ThreadsSpace.section)
            Button(PlanningCopy.skipTitle(flow.mode), action: onSkip)
                .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                .padding(.horizontal, ThreadsSpace.row)
                .frame(minHeight: ThreadsHit.minimum)
                .accessibilityIdentifier("planSkip")
        }
    }

    private func row(_ step: PlanningStep) -> some View {
        let state = status(step)
        let title = PlanningCopy.railTitle(step, mode: flow.mode)
        let line = summary(step, state)
        return Button { if state == .done { onGo(step) } } label: {
            HStack(alignment: .top, spacing: ThreadsSpace.row) {
                marker(state).padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).threadsType(.row)
                        .foregroundStyle(state == .upcoming ? threads.ink2 : threads.ink)
                        .fontWeight(state == .current ? .semibold : .regular)
                    if let line { Text(line).threadsType(.meta).foregroundStyle(threads.ink2) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ThreadsSpace.row).padding(.vertical, ThreadsSpace.row)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { if state == .current { RoundedRectangle(cornerRadius: 22, style: .continuous).fill(threads.selected) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title, line].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(state == .done ? "Done" : (state == .current ? "Current step" : "Later"))
        .accessibilityHint(state == .done ? "Goes back to this step" : "")
        .accessibilityAddTraits(state == .current ? .isSelected : [])
        .accessibilityIdentifier("planRail-\(step.rawValue)")
    }

    @ViewBuilder private func marker(_ state: Status) -> some View {
        switch state {
        case .done:
            Circle().fill(threads.accent).frame(width: 22, height: 22)
                .overlay { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(threads.onAccent) }
        case .current:
            Circle().strokeBorder(threads.terra, lineWidth: 2).frame(width: 22, height: 22)
        case .upcoming:
            Circle().strokeBorder(threads.line2, lineWidth: 1.5).frame(width: 22, height: 22)
        }
    }

    /// What each step says for itself, from the engine's reads: shown for the steps behind and the one open.
    private func summary(_ step: PlanningStep, _ state: Status) -> String? {
        guard state != .upcoming else { return nil }
        switch step {
        case .review:
            guard let review = try? flow.review() else { return nil }
            return PlanningCopy.tasksRow(done: review.doneCount, left: review.leftCount)
        case .carry:
            let items = flow.carryItems()
            let pending = items.filter { $0.state == .pending }.count
            let moved = items.filter { if case .moved = $0.state { true } else { false } }.count
            let dropped = items.filter { $0.state == .dropped }.count
            return PlanningCopy.carryRail(pending: pending, moved: moved, dropped: dropped, settled: state == .done)
        case .build:
            guard let build = try? flow.build() else { return nil }
            return PlanningCopy.buildRail(tasks: build.tasks.count, minutes: build.tasks.reduce(0) { $0 + ($1.effortMinutes ?? 0) })
        case .load, .close, .unknown:
            return nil
        }
    }
}
