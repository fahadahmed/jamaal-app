//
//  TodayViews.swift
//  JamaalWidgets
//

import SwiftUI
import WidgetKit
import ThreadsTokens
import JamaalCore

/// The Today widget's three sizes (frames WG-02 and WG-03). No checkboxes and no editing: v1 widgets are not interactive.
/// The small one shows no task titles at all. The headline's second line and the bar's fill are the accent group.

private struct Headline: View {
    @Environment(\.threads) private var threads
    let headline: TodayWidgetDisplay.Headline
    var compact = false

    var body: some View {
        Text("\(Text(headline.first + " ").font(.custom("FrauncesDisplay-Regular", size: compact ? 20 : 26, relativeTo: .title2)).foregroundStyle(threads.ink))\(Text(headline.second).font(.custom(ThreadsType.displayItalicFontName, size: compact ? 20 : 26, relativeTo: .title2)).foregroundStyle(threads.accent))")
            .lineLimit(3).minimumScaleFactor(0.7)
    }
}

private struct Eyebrow: View {
    @Environment(\.threads) private var threads
    let text: String
    var body: some View { Text(text.uppercased()).threadsType(.label).foregroundStyle(threads.ink3).lineLimit(1) }
}

/// "2h 15m of 3h" and the state word over the bar, which turns terracotta once the day is over-full.
private struct CapacityBar: View {
    @Environment(\.threads) private var threads
    let display: TodayWidgetDisplay
    var showsFigures = true
    var showsWord = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if showsFigures {
                HStack {
                    Text(display.capacityText).threadsType(.meta).foregroundStyle(threads.ink)
                    Spacer(minLength: 4)
                    if showsWord { Text(display.stateWord).threadsType(.label).foregroundStyle(display.isOver ? threads.terra : threads.ink3) }
                }.lineLimit(1).minimumScaleFactor(0.8)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(threads.line)
                    Capsule().fill(display.isOver ? threads.terra : threads.accent).widgetAccentable()
                        .frame(width: max(6, proxy.size.width * display.barFill))
                }
            }.frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(display.capacityText), \(display.stateWord.capitalized)")
    }
}

private struct WidgetTaskRow: View {
    @Environment(\.threads) private var threads
    let task: WidgetSnapshot.TaskLine
    /// The minutes sit under the title (medium) instead of beside it (large).
    var stacked = false

    var body: some View {
        HStack(alignment: stacked ? .top : .center, spacing: 8) {
            Circle().fill(JamaalPalette.categoryColor(forKey: task.categoryColorKey ?? "")).frame(width: 7, height: 7).accessibilityHidden(true)
                .padding(.top, stacked ? 7 : 0)
            if stacked {
                VStack(alignment: .leading, spacing: 0) {
                    Text(task.title).threadsType(.body).foregroundStyle(threads.ink).lineLimit(1).privacySensitive()
                    if let effort = TodayWidgetCopy.effort(task.effortMinutes) { Text(effort).threadsType(.meta).foregroundStyle(threads.ink3) }
                }
            } else {
                Text(task.title).threadsType(.body).foregroundStyle(threads.ink).lineLimit(1).privacySensitive()
            }
            Spacer(minLength: 4)
            if !stacked, let effort = TodayWidgetCopy.effort(task.effortMinutes) {
                Text(effort).threadsType(.meta).foregroundStyle(threads.ink3).lineLimit(1)
            }
        }
    }
}

private struct AnchorFooter: View {
    @Environment(\.threads) private var threads
    let display: TodayWidgetDisplay
    var showsBar = false
    /// The small widget stacks the Anchor line over the done count; the wider ones put them on one line.
    var stacked = false

    var body: some View {
        if let line = TodayWidgetCopy.anchorLine(display.anchor, time: NextAnchorSmallView.clockTime) {
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(threads.line).frame(height: 1)
                let anchorText = Text(line).threadsType(.meta).foregroundStyle(threads.accent).widgetAccentable().lineLimit(1).minimumScaleFactor(0.8)
                let doneText = display.doneLine.map { Text($0).threadsType(.meta).foregroundStyle(threads.ink3).lineLimit(1) }
                if stacked {
                    anchorText
                    if let doneText { doneText }
                } else {
                    HStack {
                        anchorText
                        Spacer(minLength: 4)
                        if let doneText { doneText }
                    }
                }
                if showsBar, let bar = display.anchorBar { WidgetBar(bar: bar) }
            }
        } else if let done = display.doneLine {
            Text(done).threadsType(.meta).foregroundStyle(threads.ink3)
        }
    }
}

private struct PlanPill: View {
    @Environment(\.threads) private var threads
    var body: some View {
        Link(destination: JamaalLink.plan.url) {
            Text("Plan tomorrow").threadsType(.body).foregroundStyle(Color.white)
                .padding(.horizontal, 18).padding(.vertical, 9).background(Capsule().fill(threads.terra))
        }
    }
}

private struct ViewOnly: View {
    @Environment(\.threads) private var threads
    var body: some View { Text("View only").threadsType(.meta).foregroundStyle(threads.ink3) }
}

// MARK: Small: the count, and how full the day is. No task titles.

struct TodaySmallView: View {
    @Environment(\.threads) private var threads
    let display: TodayWidgetDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: display.eyebrow)
            Spacer(minLength: 4)
            Headline(headline: display.headline, compact: true)
            Spacer(minLength: 6)
            if display.showsCapacity {
                CapacityBar(display: display, showsFigures: false)
                Text(display.capacityText).threadsType(.meta).foregroundStyle(threads.ink3).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 4)
            } else {
                AnchorFooter(display: display, stacked: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Medium: the headline, the bar and the next two tasks

struct TodayMediumView: View {
    let display: TodayWidgetDisplay

    var body: some View {
        GeometryReader { proxy in
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: display.eyebrow)
                Spacer(minLength: 4)
                Headline(headline: display.headline, compact: true)
                Spacer(minLength: 6)
                if display.showsCapacity { CapacityBar(display: display, showsWord: false) } else { AnchorFooter(display: display) }
            }
            .frame(width: display.mediumTasks.isEmpty ? proxy.size.width : proxy.size.width * 0.44, alignment: .leading)
            if !display.mediumTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(display.mediumTasks, id: \.id) { WidgetTaskRow(task: $0, stacked: true) }
                    if let more = display.mediumMore { MoreLine(text: more) }
                    Spacer(minLength: 0)
                    if display.showsPlanTomorrow { PlanPill() } else if display.viewOnly { ViewOnly() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct MoreLine: View {
    @Environment(\.threads) private var threads
    let text: String
    var body: some View { Text(text).threadsType(.meta).foregroundStyle(threads.ink3) }
}

// MARK: Large: five tasks with their category and minutes, and the Anchor line with its bar

struct TodayLargeView: View {
    let display: TodayWidgetDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: display.eyebrow)
            Headline(headline: display.headline)
            if display.showsCapacity { CapacityBar(display: display) }
            VStack(alignment: .leading, spacing: 9) {
                ForEach(display.largeTasks, id: \.id) { WidgetTaskRow(task: $0) }
                if let more = display.largeMore { MoreLine(text: more) }
            }.padding(.top, 2)
            Spacer(minLength: 0)
            if display.showsPlanTomorrow { PlanPill() } else if display.viewOnly { ViewOnly() }
            AnchorFooter(display: display, showsBar: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The store can't be read yet (before the app has run once): a calm line, never an error.
struct TodayEmptyView: View {
    @Environment(\.threads) private var threads
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "Today")
            Spacer()
            Text("Open Jamaal to begin.").threadsType(.body).foregroundStyle(threads.ink)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
