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

    /// The Lock Screen's words. With no snapshot it says nothing is left, calmly.
    var lockDisplay: LockScreenAnchorDisplay {
        (snapshot ?? WidgetSnapshot.empty(at: date)).lockScreenAnchorDisplay(time: NextAnchorSmallView.clockTime, shortTime: NextAnchorSmallView.shortClockTime)
    }
}

/// The fonts are registered once per process: WidgetKit may build the provider more than once, and registering a font that is
/// already registered is logged by the system each time.
enum WidgetFonts {
    static let registered: [ThreadsFonts.Failure] = ThreadsFonts.registerAll()
}

/// Reads the shared store without ever writing to it, and plans the entries from `WidgetTimeline`.
struct NextAnchorProvider: TimelineProvider {
    init() { _ = WidgetFonts.registered }

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

    /// The Lock Screen sizes are iOS only: macOS has no accessory families.
    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular]
        #else
        [.systemSmall]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextAnchorProvider()) { entry in
            NextAnchorEntryView(entry: entry)
        }
        .configurationDisplayName("Next Anchor")
        .description("The Anchor your day is moving around next.")
        .supportedFamilies(Self.families)
    }
}

struct NextAnchorEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextAnchorEntry

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            NextAnchorInlineView(display: entry.lockDisplay).widgetURL(JamaalLink.today.url)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            NextAnchorCircularView(display: entry.lockDisplay).widgetURL(JamaalLink.today.url)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            NextAnchorRectangularView(display: entry.lockDisplay).widgetURL(JamaalLink.today.url)
                .containerBackground(for: .widget) { Color.clear }
        #endif
        default:
            NextAnchorSmallView(display: entry.display)
                .environment(\.threads, JamaalPalette())
                .widgetURL(JamaalLink.today.url)
                .containerBackground(for: .widget) { JamaalPalette().app }
        }
    }
}
