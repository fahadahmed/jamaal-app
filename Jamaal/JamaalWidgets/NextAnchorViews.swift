//
//  NextAnchorViews.swift
//  JamaalWidgets
//

import SwiftUI
import WidgetKit
import ThreadsTokens
import JamaalCore

/// The small Next Anchor widget (frame WG-01). No checkboxes and no editing: v1 widgets are not interactive. The
/// accent group (`widgetAccentable`) is the Anchor name and the bar's fill; everything else renders as primary.
struct NextAnchorSmallView: View {
    @Environment(\.threads) private var threads
    let display: NextAnchorDisplay

    private var isNone: Bool { display == .noneLeft }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NextAnchorCopy.eyebrow(display))
                .threadsType(.label).foregroundStyle(threads.ink3)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            title
            if let detail = NextAnchorCopy.detail(display, time: Self.clockTime) {
                Text(detail).threadsType(.meta).foregroundStyle(threads.ink)
                    .lineLimit(1).minimumScaleFactor(0.8).padding(.top, 2)
            }
            if let bar = NextAnchorCopy.bar(display) {
                WidgetBar(bar: bar).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder private var title: some View {
        let text = NextAnchorCopy.title(display)
        if isNone {
            Text(text).font(.custom(ThreadsType.displayItalicFontName, size: 24, relativeTo: .title3))
                .foregroundStyle(threads.accent).widgetAccentable()
                .lineLimit(3).minimumScaleFactor(0.8)
        } else {
            Text(text).threadsType(.display(.compact))
                .foregroundStyle(threads.accent).widgetAccentable()
                .lineLimit(2).minimumScaleFactor(0.6)
        }
    }

    /// A clock time the way the device writes it ("15:32", or "3:32 pm").
    nonisolated static func clockTime(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    /// The same without "am" or "pm", for the circular Lock Screen widget ("15:32", or "3:32").
    nonisolated static func shortClockTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute())
    }
}

/// The window bar: the accent fill, an outline before the window opens, a neutral full bar once it is over unrecorded.
struct WidgetBar: View {
    @Environment(\.threads) private var threads
    let bar: NextAnchorCopy.Bar

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                switch bar.style {
                case .outline:
                    Capsule().strokeBorder(threads.ink3, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                case .accent:
                    Capsule().fill(threads.line)
                    Capsule().fill(threads.accent).widgetAccentable()
                        .frame(width: max(6, proxy.size.width * bar.fill))
                case .neutral:
                    Capsule().fill(threads.ink3.opacity(0.35))
                }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
