//
//  NightPlanningScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Night Planning (NP-01…06) on compact width: a full-screen flow of up to five steps, each opening with a short
/// statement. Back, close and **Skip tonight** are always there; leaving mid-flow resumes at the same step.
struct NightPlanningScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    let flow: PlanningFlow
    /// Bumped after any change and passed to the steps, so they read the engine again (it isn't observable).
    @State private var revision = 0
    @State private var summary: ClosingSummary?
    @State private var firstAnchor: String?
    /// The width of the wide canvas and where it starts, in the window's coordinates (see `railRegionWidth`).
    @State private var canvasWidth: CGFloat = 0
    /// The whole screen's width inside the safe area, to decide between the wide canvas and the single column (`PaneLayout`).
    @State private var screenWidth: CGFloat = 0
    private var twoPanes: Bool { PaneLayout.usesTwoPanes(isRegularWidth: AppNavigation.isRegular(sizeClass), availableWidth: screenWidth) }
    @State private var canvasOriginX: CGFloat = 0
    @Environment(FoldMonitor.self) private var fold: FoldMonitor?
    /// A phone held sideways is about 390 points tall: the header and the footer shrink to one row each so the step has room (#315).
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isShort: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            (flow.step == .close && flow.mode == .evening ? threads.deep : threads.app).ignoresSafeArea()
            if flow.step == .close, let summary {
                CloseStep(flow: flow, summary: summary, firstAnchor: firstAnchor) { dismiss() }
            } else if twoPanes {
                wideCanvas
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        content
                            .padding(.horizontal, ThreadsSpace.gutter)
                            .padding(.top, isShort ? ThreadsSpace.row : ThreadsSpace.section)
                            .padding(.bottom, ThreadsSpace.section)
                    }
                    .scrollIndicators(.hidden)
                    footer
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
        // Regular width that is too narrow for two panes (a Duo held fully open in portrait) draws the steps as it does on a phone too.
        .environment(\.horizontalSizeClass, twoPanes ? sizeClass : .compact)
    }

    // MARK: The wide canvas (NP-07)

    /// One canvas at regular width: the step rail on the left, the open step on the right in a readable column.
    private var wideCanvas: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                PlanningRail(flow: flow, revision: revision, onGo: { flow.go(to: $0); revision += 1 }, onSkip: { flow.skip(); dismiss() })
                    .frame(maxWidth: 340)
            }
            // A margin on the left, so the rail never touches the edge. It was a fixed 340 pt inside two fifths of the window, which is
            // narrower than that (347 pt) on half of an iPhone Duo's inner display: the rail overflowed and was clipped (#329).
            .padding(.leading, ThreadsSpace.gutter)
            .padding(.vertical, ThreadsSpace.section)
            .padding(.trailing, 32)
            .frame(width: railRegionWidth)
            Divider().overlay(threads.line)
            VStack(spacing: 0) {
                ScrollView {
                    content
                        .frame(maxWidth: 640, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 40).padding(.trailing, 24)
                        .padding(.top, ThreadsSpace.section + 36)
                        .padding(.bottom, ThreadsSpace.section)
                }
                .scrollIndicators(.hidden)
                wideFooter
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                roundButton("xmark", label: "Close") { dismiss() }.padding(.top, ThreadsSpace.tight).padding(.trailing, ThreadsSpace.gutter)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { canvasWidth = $0.width; canvasOriginX = $0.minX }
    }

    /// How wide the rail's region is: up to the crease when a foldable iPhone is held half open (the rail on one half, the step on the other),
    /// otherwise two fifths of the canvas as before (measured, so it follows a rotation).
    private var railRegionWidth: CGFloat {
        let fallback = canvasWidth > 0 ? canvasWidth * 0.4 : 400
        guard let crease = fold?.creaseX else { return fallback }
        let width = FoldLayout.listWidth(creaseX: crease, listOriginX: canvasOriginX, fallback: 0)
        return width > 0 ? width : fallback
    }

    /// Continue (hugging its title) and the keyboard hint: ⌘↵ does the same.
    private var wideFooter: some View {
        HStack(spacing: ThreadsSpace.row) {
            Button(action: advance) {
                HStack(spacing: 8) {
                    Text("Continue").threadsType(.row)
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .frame(minHeight: 56)
                .background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityIdentifier("planContinue")
            Text("⌘↵").threadsType(.label).foregroundStyle(threads.ink2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(threads.line))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 40).padding(.trailing, 24)
        .padding(.vertical, ThreadsSpace.section)
    }

    // MARK: Chrome

    @ViewBuilder private var header: some View {
        if isShort { shortHeader } else { tallHeader }
    }

    /// Landscape: back, the step's name over its progress, and close, on one row.
    private var shortHeader: some View {
        HStack(spacing: ThreadsSpace.row) {
            if !flow.isFirstStep { roundButton("chevron.left", label: "Back", size: 40) { flow.back(); revision += 1 } }
            VStack(spacing: 6) {
                Text(PlanningCopy.eyebrow(position: flow.position, count: flow.stepCount, step: flow.step, mode: flow.mode))
                    .threadsType(.label).foregroundStyle(threads.ink2)
                HStack(spacing: 6) {
                    ForEach(1...flow.stepCount, id: \.self) { index in
                        Capsule().fill(index <= flow.position ? threads.deep : threads.line).frame(height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            roundButton("xmark", label: "Close", size: 40) { dismiss() }
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, ThreadsSpace.hair)
    }

    private var tallHeader: some View {
        VStack(spacing: ThreadsSpace.row) {
            ZStack {
                Text(PlanningCopy.eyebrow(position: flow.position, count: flow.stepCount, step: flow.step, mode: flow.mode))
                    .threadsType(.label).foregroundStyle(threads.ink2)
                HStack {
                    if !flow.isFirstStep {
                        roundButton("chevron.left", label: "Back") { flow.back(); revision += 1 }
                    }
                    Spacer()
                    roundButton("xmark", label: "Close") { dismiss() }
                }
            }
            HStack(spacing: 6) {
                ForEach(1...flow.stepCount, id: \.self) { index in
                    Capsule().fill(index <= flow.position ? threads.deep : threads.line).frame(height: 4)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, ThreadsSpace.tight)
    }

    private func roundButton(_ symbol: String, label: String, size: CGFloat = 48, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var footer: some View {
        if isShort { shortFooter } else { tallFooter }
    }

    /// Landscape: Skip beside Continue, on one row.
    private var shortFooter: some View {
        HStack(spacing: ThreadsSpace.row) {
            Button(PlanningCopy.skipTitle(flow.mode)) { flow.skip(); dismiss() }
                .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                .frame(minHeight: ThreadsHit.minimum)
                .accessibilityIdentifier("planSkip")
            Button(action: advance) {
                HStack(spacing: 8) {
                    Text("Continue").threadsType(.row)
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("planContinue")
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.vertical, ThreadsSpace.hair)
        .background(threads.app)
    }

    private var tallFooter: some View {
        VStack(spacing: ThreadsSpace.tight) {
            Button(action: advance) {
                HStack(spacing: 8) {
                    Text("Continue").threadsType(.row)
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("planContinue")
            Button(PlanningCopy.skipTitle(flow.mode)) { flow.skip(); dismiss() }
                .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                .frame(minHeight: ThreadsHit.minimum)
                .accessibilityIdentifier("planSkip")
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.vertical, ThreadsSpace.tight)
        .background(threads.app)
    }

    @ViewBuilder private var content: some View {
        switch flow.step {
        case .review, .unknown: ReviewStep(flow: flow, revision: revision)
        case .carry: CarryStep(flow: flow, revision: revision) { revision += 1 }
        case .build: BuildStep(flow: flow, revision: revision) { revision += 1 }
        case .load, .close: LoadStep(flow: flow, revision: revision) { revision += 1 }
        }
    }

    // MARK: Moving on

    private func advance() {
        switch flow.step {
        case .carry:
            CarryStep.settlePending(flow)                          // anything left untouched is kept for tomorrow
            flow.next()
        case .load:
            firstAnchor = Self.firstAnchorLine(flow)
            summary = try? flow.close()
        default:
            flow.next()
        }
        revision += 1
    }

    /// "The school run at 08:15" — the first fixed Anchor of the planned day, for the closing line.
    private static func firstAnchorLine(_ flow: PlanningFlow) -> String? {
        guard let build = try? flow.build(),
              let first = build.anchors.filter({ $0.rule?.placementKind != .flexible }).min(by: { $0.windowStart < $1.windowStart }) else { return nil }
        let name = first.rule?.title ?? first.title
        if flow.mode == .morning { return "The \(name.lowercased())" }
        let time = first.windowStart.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .current, timeZone: flow.boundary.timeZone))
        return "\(name) at \(time)"
    }
}

/// A statement with its last word in italic accent: "How Monday *went.*"
struct PlanningHeadline: View {
    @Environment(\.threads) private var threads
    let headline: PlanningCopy.Headline

    var body: some View {
        Text("\(Text(headline.plain + " ").foregroundStyle(threads.ink))\(Text(headline.accent).font(.custom(ThreadsType.displayItalicFontName, size: 38, relativeTo: .largeTitle)).foregroundStyle(threads.accent))")
            .threadsType(.display(.large))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}
