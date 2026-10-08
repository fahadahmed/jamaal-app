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

    var body: some View {
        ZStack {
            (flow.step == .close && flow.mode == .evening ? threads.deep : threads.app).ignoresSafeArea()
            if flow.step == .close, let summary {
                CloseStep(flow: flow, summary: summary, firstAnchor: firstAnchor) { dismiss() }
            } else if AppNavigation.isRegular(sizeClass) {
                wideCanvas
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        content
                            .padding(.horizontal, ThreadsSpace.gutter)
                            .padding(.top, ThreadsSpace.section)
                            .padding(.bottom, ThreadsSpace.section)
                    }
                    .scrollIndicators(.hidden)
                    footer
                }
            }
        }
    }

    // MARK: The wide canvas (NP-07)

    /// One canvas at regular width: the step rail on the left, the open step on the right in a readable column.
    private var wideCanvas: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                PlanningRail(flow: flow, revision: revision, onGo: { flow.go(to: $0); revision += 1 }, onSkip: { flow.skip(); dismiss() })
                    .frame(width: 340)
            }
            .padding(.vertical, ThreadsSpace.section)
            .padding(.trailing, 32)
            .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 0)
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

    private var header: some View {
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

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var footer: some View {
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
        (Text(headline.plain + " ").foregroundStyle(threads.ink)
         + Text(headline.accent).font(.custom(ThreadsType.displayItalicFontName, size: 38, relativeTo: .largeTitle)).foregroundStyle(threads.accent))
            .threadsType(.display(.large))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}
