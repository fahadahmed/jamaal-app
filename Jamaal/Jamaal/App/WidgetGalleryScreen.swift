//
//  WidgetGalleryScreen.swift
//  Jamaal
//

#if DEBUG
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Debug only: the widgets in each of their states, light and dark, drawn by the same views as the extension. `-JamaalWidgetGalleryToday` shows
/// the Today widget (small, medium, large) instead of Next Anchor.
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

    private static func tasks(_ n: Int) -> [WidgetSnapshot.TaskLine] {
        let titles = ["Pack the swim bag", "Reply to the school", "Book the dentist", "Call Mum", "Renew the car insurance"]
        return (0..<n).map { .init(id: UUID(), title: titles[$0 % 5], effortMinutes: [10, 25, 15, 20, 30][$0 % 5], categoryColorKey: ["family", "personal", "personal", "family", "work"][$0 % 5]) }
    }
    private static func today(left: Int, done: Int = 0, planned: Int, budget: Int, state: LoadState, anchor: WidgetSnapshot.AnchorWindow?,
                              planning: Bool = false, readOnly: Bool = false) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: start, day: "2026-10-17", isReadOnly: readOnly, tasksLeft: left, tasksDone: done,
                       tasks: tasks(min(left, 5)), moreTasks: max(0, left - 5),
                       capacity: .init(plannedMinutes: planned, budgetMinutes: budget, level: "medium", state: state),
                       anchors: anchor.map { [$0] } ?? [], planningAt: start, planningDue: planning, dayEndsAt: start.addingTimeInterval(7200))
    }
    private static let todaySamples: [(String, WidgetSnapshot)] = [
        ("Four things", today(left: 4, planned: 135, budget: 180, state: .balanced, anchor: window("Dhuhr", rule: "Salah", phase: .open, progress: 0.4, from: -0.5, to: 1))),
        ("Seven, over", today(left: 7, planned: 330, budget: 240, state: .overloaded, anchor: window("Asr", rule: "Salah", phase: .upcoming, progress: 0, from: 2, to: 4))),
        ("All done", today(left: 0, done: 4, planned: 0, budget: 180, state: .light, anchor: window("Isha", rule: "Salah", phase: .upcoming, progress: 0, from: 3, to: 6))),
        ("Blank day", today(left: 0, planned: 0, budget: 180, state: .light, anchor: window("Fajr", rule: "Salah", phase: .open, progress: 0.5, from: -1, to: 1))),
        ("Evening", today(left: 1, planned: 10, budget: 180, state: .light, anchor: nil, planning: true)),
        ("Read-only", today(left: 1, planned: 10, budget: 180, state: .light, anchor: nil, planning: true, readOnly: true)),
    ]

    private func frame<V: View>(_ view: V, _ w: CGFloat, _ h: CGFloat) -> some View {
        view.padding(16).frame(width: w, height: h)
            .background(JamaalPalette().app, in: RoundedRectangle(cornerRadius: 24))
            .environment(\.threads, JamaalPalette()).environment(\.colorScheme, scheme)
    }

    /// `-JamaalWidgetGallerySkip 2` starts further down, to look at the later states without scrolling.
    private var skip: Int {
        let args = ProcessInfo.processInfo.arguments
        return args.firstIndex(of: "-JamaalWidgetGallerySkip").flatMap { Int(args[$0 + 1]) } ?? 0
    }

    private var todayGallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(Self.todaySamples.dropFirst(skip)), id: \.0) { name, snap in
                    let d = snap.todayWidgetDisplay
                    Text(name).font(.caption2).foregroundStyle(.secondary)
                    frame(TodaySmallView(display: d), 158, 158)
                    frame(TodayMediumView(display: d), 338, 158)
                    frame(TodayLargeView(display: d), 338, 354)
                }
            }.padding(14)
        }
        .background(scheme == .light ? Color(white: 0.82) : Color(white: 0.08))
        .preferredColorScheme(scheme)
    }

    #if os(iOS)
    /// `-JamaalWidgetGalleryLock` shows the Next Anchor Lock Screen widgets on a dark wallpaper, tinted white as the Lock Screen does.
    private static let lockSamples: [(String, [WidgetSnapshot.AnchorWindow], WidgetSnapshot.AnchorWindow?)] = [
        ("Open", [window("Dhuhr", rule: "Salah", phase: .open, progress: 0.12, from: -0.3, to: 2), window("Asr", rule: "Salah", phase: .upcoming, progress: 0, from: 2.1, to: 4)], nil),
        ("Upcoming", [window("School run", rule: nil, phase: .upcoming, progress: 0, from: 1, to: 2)], nil),
        ("Closing soon", [window("Asr", rule: "Salah", phase: .closingSoon, progress: 0.85, from: -2, to: 0.34)], nil),
        ("None left", [], window("Fajr", rule: "Salah", phase: .upcoming, progress: 0, from: 9, to: 10)),
        ("Needs attention", [window("Bin night", rule: nil, phase: .needsAttention, progress: 1, from: -3, to: -1)], nil),
    ]

    private var lockGallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(Self.lockSamples.enumerated()), id: \.offset) { _, sample in
                    let snap = WidgetSnapshot(generatedAt: Self.start, day: "2026-10-17", isReadOnly: false, tasksLeft: 0, tasksDone: 0, tasks: [], moreTasks: 0,
                                              capacity: .init(plannedMinutes: 0, budgetMinutes: 180, level: "medium", state: .light), anchors: sample.1,
                                              planningAt: Self.start, planningDue: false, dayEndsAt: Self.start.addingTimeInterval(7200), tomorrowAnchor: sample.2)
                    let d = snap.lockScreenAnchorDisplay(time: NextAnchorSmallView.clockTime, shortTime: NextAnchorSmallView.shortClockTime)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sample.0).font(.caption2).foregroundStyle(.white.opacity(0.6))
                        NextAnchorInlineView(display: d).font(.system(size: 14, weight: .medium))
                        HStack(spacing: 12) {
                            NextAnchorCircularView(display: d).frame(width: 72, height: 72)
                            NextAnchorRectangularView(display: d).frame(width: 160, height: 72)
                        }
                    }
                }
            }.padding(20).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [Color(red: 0.1, green: 0.22, blue: 0.3), Color(red: 0.02, green: 0.08, blue: 0.12)], startPoint: .top, endPoint: .bottom))
        .preferredColorScheme(.dark)
    }

    #endif

    var body: some View {
        let args = ProcessInfo.processInfo.arguments
        #if os(iOS)
        if args.contains("-JamaalWidgetGalleryLock") { lockGallery } else if args.contains("-JamaalWidgetGalleryToday") { todayGallery }
        else { anchorGallery }
        #else
        if args.contains("-JamaalWidgetGalleryToday") { todayGallery } else { anchorGallery }
        #endif
    }

    private var anchorGallery: some View {
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
