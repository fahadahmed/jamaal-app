//
//  AnchorsRulesView.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The rules list (AN-01): each rule with a one-line schedule, its next Anchor and its state, and an Archived section
/// with Restore. Used inside the Habits tab's Anchors segment and, on iPad and Mac, as its own sidebar item.
struct AnchorsRulesView: View {
    @Environment(\.threads) private var threads
    @Environment(\.requireAccess) private var requireAccess
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    // Observed so the list re-reads when rules change, here or on another device.
    @Query private var rules: [AnchorRule]
    @State private var now = Date.now
    /// Owned by the screen, so the Add button can sit up beside the Habits | Anchors switch on a phone.
    @Binding var adding: Bool
    var showsAddButton = true
    @State private var archivedOpen = false

    var body: some View {
        let _ = rules.map { [$0.title, $0.configData, $0.isArchived ? "1" : "0"] }
        let boundary = TodayDay.boundary(in: context)
        let overview = try? AnchorsOverview.read(in: context, now: now, boundary: boundary)
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                HStack(alignment: .center) {
                    Text("Anchors").threadsType(.display(.large)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if showsAddButton {
                        AddCircleButton(label: "Add an Anchor rule", identifier: "addAnchorRule") { if requireAccess(.createAnchorRule) { adding = true } }
                    }
                }
                if let overview {
                    if overview.rows.isEmpty && overview.archived.isEmpty {
                        Text("Prayer times, the school run, bin night: the things your day moves around.")
                            .threadsType(.lede).foregroundStyle(threads.ink2)
                    }
                    VStack(spacing: 0) {
                        ForEach(overview.rows, id: \.rule.id) { row in
                            ruleRow(row, today: boundary.logicalDate(at: now), boundary: boundary)
                            Divider().overlay(threads.line)
                        }
                    }
                    if !overview.archived.isEmpty { archivedSection(overview.archived) }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.row)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(threads.app)
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .sheet(isPresented: $adding) { AddAnchorRuleFlow() }
    }

    private func line(_ row: AnchorsOverview.Row, today: CalendarDate, boundary: DayBoundary) -> String {
        if let state = AnchorsCopy.state(row.state) { return state }
        let style = TodayCopy.TimeStyle(timeZone: boundary.timeZone, locale: .current)
        switch row.rule.config {
        case .scheduled(let config): return AnchorsCopy.scheduleLine(config, next: row.next, today: today, style: style)
        case .prayer:
            let next = row.next.map { " · next \($0.title) \(TodayCopy.time($0.windowStart, style: style))" } ?? ""
            return "Prayer times\(next)"
        case .needsAttention: return ""
        }
    }

    private func ruleRow(_ row: AnchorsOverview.Row, today: CalendarDate, boundary: DayBoundary) -> some View {
        NavigationLink(value: row.rule) {
            HStack(alignment: .top, spacing: ThreadsSpace.row) {
                if case .needsAttention = row.state {
                    Image(systemName: "exclamationmark.circle").font(.title3).foregroundStyle(threads.ink).padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.hair) {
                    Text(row.rule.title).threadsType(.row).foregroundStyle(row.state == .active ? threads.ink : threads.ink2)
                    Text(line(row, today: today, boundary: boundary)).threadsType(.meta).foregroundStyle(threads.ink2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: ThreadsSpace.tight)
                Image(systemName: "chevron.right").foregroundStyle(threads.ink3)
            }
            .padding(.vertical, ThreadsSpace.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private func archivedSection(_ archived: [AnchorRule]) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Button { withAnimation(.snappy) { archivedOpen.toggle() } } label: {
                HStack {
                    Text("ARCHIVED · \(archived.count)").threadsType(.label).foregroundStyle(threads.ink2)
                    Spacer()
                    Image(systemName: archivedOpen ? "chevron.up" : "chevron.down").foregroundStyle(threads.ink3)
                }
                .frame(minHeight: ThreadsHit.minimum).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("anchorsArchivedToggle")
            if archivedOpen {
                ForEach(archived, id: \.id) { rule in
                    HStack {
                        Text(rule.title).threadsType(.lede).foregroundStyle(threads.ink2)
                        Spacer()
                        Button("Restore") { if requireAccess(.archiveOrRestore) { rule.isArchived = false; AppEngine.syncAnchors(in: context) } }
                            .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                            .frame(minHeight: ThreadsHit.minimum)
                            .accessibilityLabel("Restore \(rule.title)")
                    }
                }
            }
        }
    }
}

/// Anchors as its own item (iPad and Mac sidebar): the same list in its own navigation.
struct AnchorsScreen: View {
    @State private var adding = false

    var body: some View {
        NavigationStack {
            AnchorsRulesView(adding: $adding)
                .navigationDestination(for: AnchorRule.self) { AnchorRuleDetailScreen(rule: $0) }
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
