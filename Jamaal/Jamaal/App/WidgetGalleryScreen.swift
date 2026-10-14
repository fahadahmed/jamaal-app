//
//  WidgetGalleryScreen.swift
//  Jamaal
//

#if DEBUG
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Debug only: the Next Anchor widget in each of its states, light and dark, drawn by the same views as the extension.
struct WidgetGalleryScreen: View {
    private static let start = Date.now
    private static func window(_ name: String, rule: String?, phase: WidgetSnapshot.AnchorPhase, progress: Double, from: Double, to: Double) -> WidgetSnapshot.AnchorWindow {
        .init(id: UUID(), name: name, ruleTitle: rule, phase: phase,
              start: start.addingTimeInterval(from * 3600), end: start.addingTimeInterval(to * 3600), progress: progress)
    }

    private static let samples: [(String, NextAnchorDisplay)] = [
        ("Open", .open(window("Dhuhr", rule: "Salah", phase: .open, progress: 0.12, from: -0.3, to: 2))),
        ("Upcoming", .upcoming(window("School run", rule: nil, phase: .upcoming, progress: 0, from: 1, to: 2))),
        ("Closing soon", .closingSoon(window("Asr", rule: "Salah", phase: .closingSoon, progress: 0.85, from: -2, to: 0.4))),
        ("None left", .noneLeft),
        ("Needs attention", .needsAttention(window("Bin night", rule: nil, phase: .needsAttention, progress: 1, from: -3, to: -1))),
    ]

    /// `-JamaalWidgetGalleryDark` draws the dark rendering instead of the light one.
    private var scheme: ColorScheme { ProcessInfo.processInfo.arguments.contains("-JamaalWidgetGalleryDark") ? .dark : .light }

    var body: some View {
        // A small widget is 158 pt square on a current iPhone; two fit across.
        ScrollView {
            LazyVGrid(columns: [GridItem(.fixed(158), spacing: 12), GridItem(.fixed(158), spacing: 12)], spacing: 12) {
                ForEach(Self.samples, id: \.0) { sample in
                    VStack(alignment: .leading, spacing: 4) {
                        NextAnchorSmallView(display: sample.1)
                            .padding(16)
                            .frame(width: 158, height: 158)
                            .background(JamaalPalette().app, in: RoundedRectangle(cornerRadius: 24))
                            .environment(\.threads, JamaalPalette())
                            .environment(\.colorScheme, scheme)
                        Text(sample.0).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
        }
        .background(scheme == .light ? Color(white: 0.82) : Color(white: 0.08))
        .preferredColorScheme(scheme)
    }
}
#endif
