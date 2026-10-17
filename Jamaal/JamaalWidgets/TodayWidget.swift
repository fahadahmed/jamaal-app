//
//  TodayWidget.swift
//  JamaalWidgets
//

import SwiftData
import SwiftUI
import WidgetKit
import ThreadsTokens
import JamaalCore

struct TodayEntry: TimelineEntry {
    let date: Date
    /// Nil when the shared store can't be read yet: the widget says so quietly, as an empty day.
    let snapshot: WidgetSnapshot?

    var display: TodayWidgetDisplay? { snapshot?.todayWidgetDisplay }
}

/// Same shared, read-only store and the same planned moments as the Next Anchor widget.
struct TodayProvider: TimelineProvider {
    init() { _ = WidgetFonts.registered }

    func placeholder(in context: Context) -> TodayEntry { TodayEntry(date: .now, snapshot: nil) }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        Task { @MainActor in completion(TodayEntry(date: .now, snapshot: try? WidgetStore.snapshot(at: .now))) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let now = Date.now
            guard let first = try? WidgetStore.snapshot(at: now) else {
                completion(Timeline(entries: [TodayEntry(date: now, snapshot: nil)], policy: .after(now.addingTimeInterval(15 * 60))))
                return
            }
            let plan = WidgetTimeline.plan(for: first, now: now)
            let entries = plan.entryDates.map { date in TodayEntry(date: date, snapshot: (try? WidgetStore.snapshot(at: date)) ?? first) }
            completion(Timeline(entries: entries, policy: .after(plan.reloadAfter)))
        }
    }
}

struct TodayWidget: Widget {
    let kind = "Today"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayEntryView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("What is left today, and how full the day is.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        Group {
            if let display = entry.display {
                switch family {
                case .systemMedium: TodayMediumView(display: display)
                case .systemLarge: TodayLargeView(display: display)
                default: TodaySmallView(display: display)
                }
            } else {
                TodayEmptyView()
            }
        }
        .environment(\.threads, JamaalPalette())
        // The pill opens Night Planning; the rest of the widget opens Today.
        .widgetURL(JamaalLink.today.url)
        .containerBackground(for: .widget) { JamaalPalette().app }
    }
}
