//
//  NextAnchorLockViews.swift
//  JamaalWidgets
//

#if os(iOS)
import SwiftUI
import WidgetKit
import JamaalCore

/// The Next Anchor Lock Screen widgets (frame WG-02). The Lock Screen renders them in one tint ("vibrant"): primary at full
/// strength, secondary at about 70%, tracks at 25%. The Anchor name and the fills are the accent group. Colours come from the
/// system here, not the palette, because the system tints these. They are not interactive.

struct NextAnchorInlineView: View {
    let display: LockScreenAnchorDisplay
    var body: some View {
        // Inline is a single line the system draws beside the date; it can't be styled further.
        Text(display.inline)
    }
}

struct NextAnchorCircularView: View {
    let display: LockScreenAnchorDisplay

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ring
            VStack(spacing: 0) {
                Text(display.circular.label).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.6)
                    .opacity(0.7).widgetAccentable()
                Text(display.circular.value).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(display.circular.label), \(display.circular.value)")
    }

    @ViewBuilder private var ring: some View {
        switch display.circular.ring {
        case .progress(let fill):
            Circle().stroke(.primary.opacity(0.25), lineWidth: 3)
            Circle().trim(from: 0, to: max(0.03, fill)).stroke(.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90)).widgetAccentable()
        case .outline:
            Circle().stroke(.primary.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [2, 3]))
        case .neutral:
            Circle().stroke(.primary.opacity(0.5), lineWidth: 3)
        case .none:
            EmptyView()
        }
    }
}

struct NextAnchorRectangularView: View {
    let display: LockScreenAnchorDisplay

    var body: some View {
        HStack(spacing: 8) {
            NextAnchorCircularView(display: display).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(display.rectangular.title).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6).widgetAccentable()
                if let subtitle = display.rectangular.subtitle {
                    Text(subtitle).font(.system(size: 12)).opacity(0.7).lineLimit(1).minimumScaleFactor(0.8)
                }
                if let bar = display.rectangular.bar { LockBar(bar: bar) }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LockBar: View {
    let bar: NextAnchorCopy.Bar
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                switch bar.style {
                case .outline: Capsule().strokeBorder(.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                case .accent:
                    Capsule().fill(.primary.opacity(0.25))
                    Capsule().fill(.primary).frame(width: max(4, proxy.size.width * bar.fill)).widgetAccentable()
                case .neutral: Capsule().fill(.primary.opacity(0.5))
                }
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}
#endif
