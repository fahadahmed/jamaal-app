//
//  SyncStatusScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// iCloud sync: whether it is on, whether this device can reach an iCloud account, when it last received and sent, and the last
/// problem it ran into. For when a device doesn't show what another one does; Copy details gives one block of text to paste when
/// asking for help (it holds no tasks, habits or titles).
struct SyncStatusScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    private let monitor = SyncMonitor.shared
    @State private var copied = false

    var body: some View {
        let now = Date.now
        let activity = monitor.activity
        SettingsPage(title: "iCloud sync") {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                Text(SyncStatusCopy.headline(isOn: monitor.isOn, account: monitor.account, activity: activity, now: now))
                    .threadsType(.lede).foregroundStyle(threads.ink).accessibilityIdentifier("syncHeadline")
                if monitor.isOn {
                    VStack(spacing: 0) {
                        Divider().overlay(threads.line)
                        line("iCloud account", SyncStatusCopy.accountText(monitor.account).capitalizedFirst)
                        line("Last received", SyncStatusCopy.when(activity.lastImportAt, now: now).capitalizedFirst)
                        line("Last sent", SyncStatusCopy.when(activity.lastExportAt, now: now).capitalizedFirst)
                        if let error = activity.lastError, let kind = activity.lastErrorKind {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last problem").threadsType(.lede).foregroundStyle(threads.ink)
                                Text("\(error) (\(SyncStatusCopy.kindText(kind)), \(SyncStatusCopy.when(activity.lastErrorAt, now: now)))")
                                    .threadsType(.body).foregroundStyle(threads.ink2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, ThreadsSpace.row)
                            .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Text("Changes can take a minute to travel. Open Jamaal on both devices and give it a moment.")
                        .threadsType(.body).foregroundStyle(threads.ink2)
                }
                Button(action: copy) {
                    Text(copied ? "Copied" : "Copy details").threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 56).overlay(Capsule().strokeBorder(threads.ink, lineWidth: 1)).contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("copySyncDetails")
                ShareLink(item: detailsText) {
                    Text("Share details").threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 56).overlay(Capsule().strokeBorder(threads.ink, lineWidth: 1)).contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shareSyncDetails")
            }
        }
        .task { await monitor.refreshAccount() }
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).threadsType(.lede).foregroundStyle(threads.ink)
            Spacer(minLength: ThreadsSpace.tight)
            Text(value).threadsType(.lede).foregroundStyle(threads.ink2)
        }
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
        .accessibilityElement(children: .combine)
    }

    /// What Copy and Share send: the sync state, this build, the habit-minutes records and the last events. No titles, notes or places.
    private var detailsText: String {
        SyncStatusCopy.details(
            isOn: monitor.isOn, account: monitor.account, activity: monitor.activity,
            container: SyncMode.containerID, device: ReminderCenter.deviceName, now: .now,
            extra: SyncDiagnostics.timedHabitLines(in: context, today: TodayDay.boundary(in: context).logicalDate(at: .now))
                + Diag.shared.reportLines())
    }

    private func copy() {
        let text = detailsText
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        copied = true
    }

    /// A short value for the Settings list.
    static var homeValue: String { SyncMonitor.shared.isOn ? "On" : "Off" }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
