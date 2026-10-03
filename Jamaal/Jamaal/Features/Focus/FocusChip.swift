//
//  FocusChip.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The ambient chip above the tab bar, on every tab, while a session is live: the task's title, a count-up timer
/// in a terracotta pill, and — when one is closing or about to open — a single Anchor line. It looks the same
/// when a session has run past its estimate: no red, no alarm.
struct FocusChip: View {
    @Environment(\.threads) private var threads
    let session: WorkSession
    let edge: ApproachingEdge?
    let onTap: () -> Void

    private var title: String { session.task?.title ?? session.habitWindow?.habit?.title ?? "" }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThreadsSpace.row) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).threadsType(.row).foregroundStyle(threads.ink).lineLimit(1)
                    if let edge {
                        Text(FocusCopy.edgeLine(edge)).threadsType(.meta).foregroundStyle(threads.ink2).lineLimit(1)
                    }
                }
                Spacer(minLength: ThreadsSpace.tight)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = FocusSessions.elapsedSeconds(of: session, at: context.date)
                    Text(FocusCopy.clock(seconds))
                        .font(.custom("JetBrainsMono-Medium", size: 16, relativeTo: .body))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(session.pausedAt == nil ? threads.terra : threads.ink3))
                        .accessibilityLabel(session.pausedAt == nil ? "Timing" : "Paused")
                        .accessibilityValue(FocusCopy.clock(seconds))
                }
            }
            .padding(.horizontal, ThreadsSpace.row)
            .frame(minHeight: ThreadsHit.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the timer")
        .accessibilityIdentifier("focusChip")
    }
}

/// The five-second toast after Done, in the chip's place: "Done · title  Undo".
struct UndoToast: View {
    @Environment(\.threads) private var threads
    let title: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(FocusCopy.doneToast(title)).threadsType(.row).foregroundStyle(threads.ink).lineLimit(1)
            Spacer(minLength: ThreadsSpace.tight)
            Button("Undo", action: onUndo)
                .threadsType(.row).foregroundStyle(threads.ink)
                .frame(minHeight: ThreadsHit.minimum)
                .accessibilityIdentifier("undoButton")
        }
        .padding(.horizontal, ThreadsSpace.row)
        .frame(minHeight: ThreadsHit.minimum)
        .accessibilityElement(children: .contain)
    }
}
