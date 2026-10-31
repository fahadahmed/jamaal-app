//
//  FocusScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The focus screen (FS-02): the task's category and title, the timer against the estimate, the note's
/// checklist (tappable), and Pause / Resume and Finish. Overrunning the estimate changes nothing here.
struct FocusScreen: View {
    @Environment(\.threads) private var threads
    @Environment(FocusCoordinator.self) private var coordinator
    let session: WorkSession
    @State private var finishing = false
    /// Where a foldable iPhone's crease is, if there is one (#329); optional so a screen built without it still works.
    @Environment(FoldMonitor.self) private var fold: FoldMonitor?
    /// This screen's frame in the window's coordinates, to turn the crease's y into the height of the top pane.
    @State private var screenFrame: CGRect = .zero

    private var task: TaskItem? { session.task }
    private var title: String { task?.title ?? session.habitWindow?.habit?.title ?? "" }
    private var isPaused: Bool { session.pausedAt != nil }

    /// Held half open like a laptop (tabletop), the display above the crease is the timer and the half below holds the controls.
    private var tabletopHeight: CGFloat? {
        FoldLayout.topPaneHeight(creaseY: fold?.creaseY, originY: screenFrame.minY, availableHeight: screenFrame.height)
    }

    var body: some View {
        Group {
            if let top = tabletopHeight {
                // The back button is a real toolbar item here, so the system draws and places it (glass, 44 pt, clear of the status
                // bar and the Duo's side pills); the bar is transparent and its scheme is dark so the control reads on the teal.
                NavigationStack {
                    tabletop(topHeight: top)
                        .navigationBarBackButtonHidden()
                        .inlineNavigationTitle()
                        .clearNavigationBarBackground()
                        .toolbar { ToolbarItem(placement: .jamaalLeading) { systemBackButton } }
                        .darkNavigationBar()
                }
            } else { standard }
        }
        .background(threads.app)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
        .sheet(isPresented: $finishing) { FinishSheet(session: session) }
    }

    private var standard: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                    Text(title).threadsType(.display(.regular)).foregroundStyle(threads.ink)
                        .accessibilityAddTraits(.isHeader)
                    timer(onDeep: false)
                    Divider().overlay(threads.line)
                    checklist
                }
                .padding(.horizontal, ThreadsSpace.gutter)
                .padding(.top, ThreadsSpace.section)
            }
            controls
        }
    }

    /// FS-02 tabletop (Duo-tabletop-FS-02): the teal half above the crease shows what is in focus, the paper half below it has the
    /// note's checklist and the controls, so nothing the hand needs sits on the fold. Nothing is added to what the screen already does.
    private func tabletop(topHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: ThreadsSpace.row) {
                Text(kicker).threadsType(.label).foregroundStyle(threads.onDeep.opacity(0.7))
                Text(title).threadsType(.display(.compact)).foregroundStyle(threads.onDeep)
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                timer(onDeep: true)
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.bottom, 28)                                   // clear of the crease's margin
            .frame(maxWidth: .infinity)
            .frame(height: topHeight)
            .background(alignment: .top) { threads.deep.ignoresSafeArea(edges: [.top, .horizontal]) }
            ScrollView {
                checklist
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ThreadsSpace.gutter)
                    .padding(.top, 28)                              // clear of the crease's margin
            }
            controls
        }
    }

    private var kicker: String {
        "IN FOCUS" + (task?.category.map { $0.name.isEmpty ? "" : " · " + $0.name.uppercased() } ?? "")
    }

    // MARK: Pieces

    /// The tabletop layout's back button, inside a navigation bar: the system supplies the glass and the size.
    private var systemBackButton: some View {
        Button { coordinator.isShowingFocus = false } label: { Image(systemName: "chevron.down") }
            .accessibilityLabel("Back to Today")
    }

    private func backButton() -> some View {
        Button { coordinator.isShowingFocus = false } label: {
            Image(systemName: "chevron.down").font(.body.weight(.semibold)).frame(width: 48, height: 48)
                .foregroundStyle(threads.ink)
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to Today")
    }

    private var topBar: some View {
        ZStack {
            HStack {
                backButton()
                Spacer()
            }
            if let category = task?.category, !category.name.isEmpty {
                HStack(spacing: 8) {
                    Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 9, height: 9)
                    Text(category.name).threadsType(.body).foregroundStyle(threads.ink2)
                }
            }
        }
        .padding(.horizontal, ThreadsSpace.row)
        .padding(.top, ThreadsSpace.tight)
    }

    /// The elapsed time against the estimate; `onDeep` draws it for the teal panel of the tabletop layout.
    private func timer(onDeep: Bool) -> some View {
        let strong = onDeep ? threads.onDeep : threads.ink
        let quiet = onDeep ? threads.onDeep.opacity(0.7) : threads.ink2
        return TimelineView(.periodic(from: .now, by: 1)) { context in
            // On the teal panel the estimate sits under the numeral, centred, as Duo-tabletop-FS-02 draws it; elsewhere it follows it.
            let layout = onDeep ? AnyLayout(VStackLayout(spacing: ThreadsSpace.tight)) : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: ThreadsSpace.row))
            layout {
                let clock = FocusCopy.clock(FocusSessions.elapsedSeconds(of: session, at: context.date))
                Group { if onDeep { HeroNumeral(clock) } else { ThreadsNumeral(clock, size: .large) } }
                    .foregroundStyle(isPaused ? (onDeep ? threads.onDeep.opacity(0.5) : threads.ink3) : strong)
                if isPaused {
                    Text("Paused").threadsType(.label).foregroundStyle(quiet)
                } else if let estimate = FocusCopy.ofEstimate(session.estimateMinutes) {
                    Text(estimate).threadsType(.body).foregroundStyle(quiet)
                }
            }
        }
    }

    @ViewBuilder private var checklist: some View {
        let items = TaskNotes.items(task?.notes)
        if !items.isEmpty, let task {
            VStack(alignment: .leading, spacing: ThreadsSpace.row) {
                ForEach(items, id: \.line) { item in
                    switch item.kind {
                    case .checkbox(let isDone):
                        Button {
                            if let updated = TaskNotes.toggled(task.notes, line: item.line) { task.notes = updated }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: ThreadsSpace.row) {
                                CheckSquare(isDone: isDone)
                                Text(Self.inline(item.text)).threadsType(.lede)
                                    .strikethrough(isDone, color: threads.ink3)
                                    .foregroundStyle(isDone ? threads.ink3 : threads.ink)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(minHeight: ThreadsHit.minimum, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(Self.inline(item.text).characters))
                        .accessibilityValue(isDone ? "Done" : "Not done")
                    case .text:
                        Text(Self.inline(item.text)).threadsType(.lede).foregroundStyle(threads.ink)
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: ThreadsSpace.tight) {
            Button {
                isPaused ? coordinator.resume(session) : coordinator.pause(session)
            } label: {
                Label(FocusCopy.pauseTitle(isPaused: isPaused), systemImage: isPaused ? "play.fill" : "pause.fill")
                    .threadsType(.row).foregroundStyle(threads.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
            }
            .accessibilityIdentifier("pauseButton")
            Button { finishing = true } label: {
                Text("Finish").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .accessibilityIdentifier("finishButton")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.vertical, ThreadsSpace.tight)
    }

    private static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(markdown)
    }
}

/// Finish (FS-05): actual against estimate, one optional line for the note, and **Done** or **Stop for now**.
struct FinishSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    @Environment(FocusCoordinator.self) private var coordinator
    let session: WorkSession
    @State private var note = ""

    private var seconds: Int { FocusSessions.elapsedSeconds(of: session, at: .now) }
    private var isTask: Bool { session.task != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            Text(session.task?.title ?? session.habitWindow?.habit?.title ?? "")
                .threadsType(.display(.compact)).foregroundStyle(threads.ink)
            Text(FocusCopy.actualVersusEstimate(seconds: seconds, estimate: session.estimateMinutes))
                .threadsType(.lede).foregroundStyle(threads.ink)
            if isTask {
                Text("A line for the note · optional").threadsType(.label).foregroundStyle(threads.ink2)
                    .padding(.top, ThreadsSpace.tight)
                TextField("Sent to Priya; waiting on costs", text: $note)
                    .threadsType(.lede)
                    .padding(ThreadsSpace.rowPadding)
                    .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.field).strokeBorder(threads.line2, lineWidth: 1))
                    .accessibilityLabel("A line for the note")
            }
            HStack(spacing: ThreadsSpace.tight) {
                Button { finish(.done) } label: {
                    Label(isTask ? "Done" : "Log it", systemImage: "checkmark").threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
                }
                .accessibilityIdentifier("doneButton")
                Button { finish(.stopForNow) } label: {
                    Text("Stop for now").threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 56).overlay(Capsule().strokeBorder(threads.line2, lineWidth: 1))
                }
                .accessibilityIdentifier("stopForNowButton")
            }
            .buttonStyle(.plain)
            .padding(.top, ThreadsSpace.tight)
            Text(FocusCopy.stopForNowNote(seconds: seconds)).threadsType(.meta).foregroundStyle(threads.ink2)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, ThreadsSpace.section)
        .padding(.bottom, ThreadsSpace.row)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(threads.app)
        .presentationDetents([.height(isTask ? 430 : 330)])
        .presentationDragIndicator(.visible)
    }

    private func finish(_ choice: FinishChoice) {
        dismiss()
        coordinator.finish(session, as: choice, note: note)
    }
}

/// The settle sheet (FS-07): a second Begin while one is running. The running one is settled first, its time
/// kept whichever is chosen.
struct SettleSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.requireAccess) private var requireAccess
    @Environment(FocusCoordinator.self) private var coordinator
    let settling: FocusCoordinator.Settling

    private var session: WorkSession { settling.session }
    private var isTask: Bool { session.task != nil }
    private var title: String { session.task?.title ?? session.habitWindow?.habit?.title ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(FocusCopy.settleEyebrow(minutes: FocusSessions.elapsedSeconds(of: session, at: context.date) / 60))
                    .threadsType(.label).foregroundStyle(threads.ink2)
            }
            Text(title).threadsType(.display(.compact)).foregroundStyle(threads.ink)
            Text(FocusCopy.settleLine).threadsType(.lede).foregroundStyle(threads.ink)

            Button { coordinator.settle(isTask ? .done : .logIt) } label: {
                Label(isTask ? "Done" : "Log it", systemImage: "checkmark").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .accessibilityIdentifier("settleDone")
            PillButton(title: "Stop for now", fills: true) { coordinator.settle(.stopForNow) }
                .accessibilityIdentifier("settleStop")
            if isTask {
                HStack(spacing: ThreadsSpace.tight) {
                    PillButton(title: "Defer to tomorrow", fills: true) { if requireAccess(.deferTask) { coordinator.settle(.deferToTomorrow) } }
                    Button { if requireAccess(.dropTask) { coordinator.settle(.drop) } } label: {
                        Text("Drop").threadsType(.row).foregroundStyle(threads.alert)
                            .frame(maxWidth: .infinity, minHeight: ThreadsHit.minimum).background(Capsule().fill(threads.alertSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider().overlay(threads.line)
            HStack {
                Text(FocusCopy.thenBegin(settling.pendingTitle)).threadsType(.body).foregroundStyle(threads.ink2).lineLimit(1)
                Spacer()
                Button("Cancel") { coordinator.cancelSettle() }
                    .threadsType(.row).foregroundStyle(threads.ink)
                    .frame(minHeight: ThreadsHit.minimum)
                    .accessibilityIdentifier("settleCancel")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, ThreadsSpace.gutter)
        .padding(.top, ThreadsSpace.section)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(threads.app)
        .presentationDetents([.height(isTask ? 520 : 420)])
        .presentationDragIndicator(.visible)
    }
}
