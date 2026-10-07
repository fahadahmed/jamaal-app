//
//  HabitRows.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// A habit window on Today. The control depends on the kind: a tick (binary), a − | + stepper (counted), minutes so
/// far (timed; Begin arrives with the focus chip), or Slip and Held today (avoid).
struct HabitRowView: View {
    @Environment(\.threads) private var threads
    let row: TodayHabitRow
    let onAction: (HabitLogAction) -> Void
    var onBegin: () -> Void = {}
    var onAddMinutes: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: ThreadsSpace.row) {
            if row.kind == .binary {
                Button { onAction(.toggle) } label: { CheckCircle(isDone: row.isDone) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(row.isDone ? "Mark \(row.title) not done" : "Mark \(row.title) done")
            } else if row.kind == .avoid && row.isDone {
                CheckCircle(isDone: true).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                Text(row.title).threadsType(.row).foregroundStyle(row.isDone ? threads.ink2 : threads.ink)
                if let detail = TodayCopy.habitDetail(kind: row.kind, amount: row.amount, target: row.target, isDone: row.isDone) {
                    Text(detail).threadsType(.meta).foregroundStyle(threads.ink2)
                }
            }
            Spacer(minLength: ThreadsSpace.tight)
            control
        }
        .padding(.vertical, ThreadsSpace.tight)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var control: some View {
        switch row.kind {
        case .counted:
            StepperPill(title: row.title, canDecrement: row.amount > 0, onDecrement: { onAction(.decrement) }, onIncrement: { onAction(.increment) })
        case .avoid where row.isDone:
            Button("Undo") { onAction(.undoHeld) }
                .threadsType(.row).foregroundStyle(threads.accent).buttonStyle(.plain)
                .frame(minHeight: ThreadsHit.minimum)
                .accessibilityLabel("Undo held today for \(row.title)")
        case .avoid:
            HStack(spacing: ThreadsSpace.tight) {
                PillButton(title: "Slip", dashed: true) { onAction(.logSlip) }
                    .accessibilityLabel("Log a slip for \(row.title)")
                PillButton(title: "Held today") { onAction(.heldToday) }
                    .accessibilityLabel("Held today: \(row.title)")
            }
        case .timed where !row.isDone:
            HStack(spacing: ThreadsSpace.tight) {
                Button(action: onAddMinutes) {
                    Image(systemName: "plus").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                        .frame(width: ThreadsHit.minimum, height: ThreadsHit.minimum).contentShape(Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Add minutes to \(row.title)")
                PillButton(title: "Begin", action: onBegin)
                    .accessibilityLabel("Begin \(row.title)")
            }
        case .binary, .timed, .unknown:
            EmptyView()
        }
    }
}

/// A habit group as a pill ("Morning  2 of 3") that opens into its habits. (The group's own sheet comes with the
/// Habits tab; until then it opens in place so every habit stays reachable.)
struct HabitGroupView: View {
    @Environment(\.threads) private var threads
    let group: TodayHabitGroup
    let onAction: (TodayHabitRow, HabitLogAction) -> Void
    var onBegin: (TodayHabitRow) -> Void = { _ in }
    var onAddMinutes: (TodayHabitRow) -> Void = { _ in }
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.snappy) { isOpen.toggle() } } label: {
                HStack(spacing: ThreadsSpace.tight) {
                    Text(group.title).threadsType(.row).foregroundStyle(threads.ink)
                    Text(TodayCopy.groupPill(done: group.done, total: group.total)).threadsType(.meta).foregroundStyle(threads.ink2)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down").font(.footnote).foregroundStyle(threads.ink3)
                }
                .padding(ThreadsSpace.chipPadding)
                .frame(minHeight: ThreadsHit.minimum)
                .overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.title), \(TodayCopy.groupPill(done: group.done, total: group.total))")
            .accessibilityHint(isOpen ? "Hides its habits" : "Shows its habits")

            if isOpen {
                ForEach(group.rows, id: \.window.id) { row in
                    HabitRowView(row: row, onAction: { onAction(row, $0) }, onBegin: { onBegin(row) }, onAddMinutes: { onAddMinutes(row) })
                    if row.window.id != group.rows.last?.window.id { Divider().overlay(threads.line) }
                }
                .padding(.top, ThreadsSpace.hair)
            }
        }
    }
}
