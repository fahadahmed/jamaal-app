//
//  LockedSheet.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The calm answer to a locked action (SB-03): what is needed, that everything already here keeps working, and the way
/// to subscribe. Never the full paywall's pressure.
struct LockedSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    let onSubscribe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                Text(SubscriptionCopy.lockedTitle).threadsType(.display(.compact)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                Text(SubscriptionCopy.lockedBody).threadsType(.lede).foregroundStyle(threads.ink2)
            }
            HStack(spacing: ThreadsSpace.tight) {
                Button(action: onSubscribe) {
                    Text("Subscribe").threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
                }
                .accessibilityIdentifier("lockedSubscribe")
                Button { dismiss() } label: {
                    Text("Not now").threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 56).overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1)).contentShape(Capsule())
                }
                .accessibilityIdentifier("lockedNotNow")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(threads.app)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lockedSheet")
    }
}
