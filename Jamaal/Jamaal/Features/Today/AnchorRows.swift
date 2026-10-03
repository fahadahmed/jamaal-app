//
//  AnchorRows.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens
import JamaalCore

/// A single Anchor on Today: the tick (Attended, only while the window is open), the title and its trailing
/// figure, the quiet second line, and the window bar. Tapping the row opens its other choices.
struct AnchorRowView: View {
    @Environment(\.threads) private var threads
    let row: TodayAnchorRow
    var showsBar = true
    let onTick: () -> Void
    let onOpen: () -> Void

    private var decided: Bool { row.status != .pending && row.status != .unknown }
    private var canTick: Bool {
        (row.status == .pending && (row.state == .open || row.state == .closingSoon)) || (row.status == .attended && row.state != .closed)
    }
    private var detail: String {
        TodayCopy.anchorDetail(
            status: row.status, state: row.state, windowStart: row.anchor.windowStart, windowEnd: row.anchor.windowEnd,
            resolvedAt: row.anchor.resolvedAt, effortMinutes: row.anchor.effortMinutes, endsToday: row.endsToday
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: ThreadsSpace.row) {
            Button(action: onTick) { CheckCircle(isDone: row.status == .attended, isMuted: !canTick) }
                .buttonStyle(.plain)
                .disabled(!canTick)
                .accessibilityLabel(row.status == .attended ? "Undo \(row.title)" : "Mark \(row.title) attended")
                .accessibilityHint(row.state == .upcoming ? detail : "")
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.title).threadsType(.row).foregroundStyle(decided ? threads.ink2 : threads.ink)
                        Spacer(minLength: ThreadsSpace.tight)
                        if let trailing = TodayCopy.anchorTrailing(
                            state: row.state, windowStart: row.anchor.windowStart, dayNumber: row.dayNumber, totalDays: row.totalDays
                        ) {
                            Text(trailing).threadsType(.label).foregroundStyle(threads.ink2)
                        }
                    }
                    Text(detail).threadsType(.meta).foregroundStyle(threads.ink2)
                    if showsBar {
                        WindowBar(progress: row.progress, state: row.state, isDecided: decided)
                            .padding(.top, ThreadsSpace.hair)
                    }
                }
                .padding(.top, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows your choices")
        }
        .padding(.vertical, ThreadsSpace.hair)
    }
}

/// A rule that yields several Anchors today: one collapsed row ("Salah 1/5 · Dhuhr · until 15:32") that opens
/// into its members.
struct AnchorGroupRowView: View {
    @Environment(\.threads) private var threads
    let group: TodayAnchorGroup
    let onTick: (TodayAnchorRow) -> Void
    let onOpen: (TodayAnchorRow) -> Void
    @State private var isOpen = false

    private var allAttended: Bool { group.isAllDecided && group.counting > 0 && group.attended == group.counting }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.snappy) { isOpen.toggle() } } label: {
                HStack(alignment: .top, spacing: ThreadsSpace.row) {
                    CheckCircle(isDone: allAttended, isMuted: false)
                    VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.title).threadsType(.row).foregroundStyle(group.isAllDecided ? threads.ink2 : threads.ink)
                            Spacer(minLength: ThreadsSpace.tight)
                            Text(TodayCopy.groupCount(attended: group.attended, counting: group.counting))
                                .threadsType(.label).foregroundStyle(threads.ink2)
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down").foregroundStyle(threads.ink3)
                        }
                        Text(TodayCopy.groupDetail(
                            nextTitle: group.next?.anchor.title, nextState: group.next?.state,
                            nextStart: group.next?.anchor.windowStart, nextEnd: group.next?.anchor.windowEnd,
                            allDecided: group.isAllDecided
                        ))
                        .threadsType(.meta).foregroundStyle(threads.ink2)
                        if let next = group.next {
                            WindowBar(progress: next.progress, state: next.state, isDecided: false).padding(.top, ThreadsSpace.hair)
                        }
                    }
                    .padding(.top, 9)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.title), \(TodayCopy.groupCount(attended: group.attended, counting: group.counting))")
            .accessibilityHint(isOpen ? "Hides each one" : "Shows each one")

            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.members, id: \.anchor.id) { member in
                        AnchorRowView(row: member, showsBar: false, onTick: { onTick(member) }, onOpen: { onOpen(member) })
                    }
                }
                .padding(.leading, ThreadsSpace.gutter)
            }
        }
        .padding(.vertical, ThreadsSpace.hair)
    }
}
