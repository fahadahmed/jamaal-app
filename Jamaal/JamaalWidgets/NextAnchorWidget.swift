//
//  NextAnchorWidget.swift
//  JamaalWidgets
//

import SwiftData
import SwiftUI
import WidgetKit
import ThreadsTokens
import JamaalCore

struct NextAnchorEntry: TimelineEntry {
    let date: Date
    /// Nil when the shared store can't be read yet (no App Group, or the app hasn't run): the widget says so quietly.
    let snapshot: WidgetSnapshot?

    var display: NextAnchorDisplay { snapshot?.nextAnchorDisplay ?? .noneLeft }
}

/// Reads the shared store without ever writing to it, and plans the entries from `WidgetTimeline`.
struct NextAnchorProvider: TimelineProvider {
    init() { _ = ThreadsFonts.registerAll() }

    func placeholder(in context: Context) -> NextAnchorEntry { NextAnchorEntry(date: .now, snapshot: nil) }

    func getSnapshot(in context: Context, completion: @escaping (NextAnchorEntry) -> Void) {
        Task { @MainActor in completion(NextAnchorEntry(date: .now, snapshot: try? WidgetStore.snapshot(at: .now))) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAnchorEntry>) -> Void) {
        Task { @MainActor in
            let now = Date.now
            guard let first = try? WidgetStore.snapshot(at: now) else {
                completion(Timeline(entries: [NextAnchorEntry(date: now, snapshot: nil)], policy: .after(now.addingTimeInterval(15 * 60))))
                return
            }
            let plan = WidgetTimeline.plan(for: first, now: now)
            let entries = plan.entryDates.map { date in NextAnchorEntry(date: date, snapshot: (try? WidgetStore.snapshot(at: date)) ?? first) }
            completion(Timeline(entries: entries, policy: .after(plan.reloadAfter)))
        }
    }
}

struct NextAnchorWidget: Widget {
    let kind = "NextAnchor"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextAnchorProvider()) { entry in
            NextAnchorEntryView(entry: entry)
        }
        .configurationDisplayName("Next Anchor")
        .description("The Anchor your day is moving around next.")
        .supportedFamilies([.systemSmall])
    }
}

struct NextAnchorEntryView: View {
    let entry: NextAnchorEntry

    var body: some View {
        NextAnchorSmallView(display: entry.display)
            .environment(\.threads, JamaalPalette())
            .widgetURL(JamaalLink.today.url)
            .containerBackground(for: .widget) { JamaalPalette().app }
    }
}
