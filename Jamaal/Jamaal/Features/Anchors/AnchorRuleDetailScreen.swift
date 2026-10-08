//
//  AnchorRuleDetailScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// A rule's detail (AN-02): its schedule, its exceptions (AN-06) and the days it will make next, from the generator's
/// dry run. Edit, Pause (an exception from today) and Archive.
struct AnchorRuleDetailScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.requireAccess) private var requireAccess
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let rule: AnchorRule
    /// In the pane beside the list (regular width): no back button, and archiving clears the selection.
    var embedded = false
    var onClose: () -> Void = {}
    private func closeOrPop() { embedded ? onClose() : dismiss() }
    @Query private var rules: [AnchorRule]
    @State private var editing = false
    @State private var excepting = false
    @State private var now = Date.now

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }
    private var today: CalendarDate { boundary.logicalDate(at: now) }
    private var style: TodayCopy.TimeStyle { TodayCopy.TimeStyle(timeZone: boundary.timeZone, locale: .current) }
    private var scheduled: ScheduledConfig? {
        if case .scheduled(let config) = rule.config { config } else { nil }
    }
    private var prayer: PrayerConfig? {
        if case .prayer(let config) = rule.config { config } else { nil }
    }
    /// The breaks of either kind of readable rule.
    private var breaks: [AnchorException]? { scheduled?.exceptions ?? prayer?.exceptions }

    var body: some View {
        let _ = rules.map { [$0.title, $0.configData, $0.isArchived ? "1" : "0"] }
        let overview = try? AnchorsOverview.read(in: context, now: now, boundary: boundary)
        let row = overview?.rows.first { $0.rule.id == rule.id }
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text(AnchorsCopy.typeTitle(rule.source).uppercased()).threadsType(.label).foregroundStyle(threads.ink2)
                    Text(rule.title).threadsType(.display(.large)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                    Text(summary(row)).threadsType(.lede).foregroundStyle(threads.ink2).accessibilityIdentifier("ruleSummary")
                }
                if let breaks { exceptions(breaks) }
                upcoming
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, 76)
            .padding(.bottom, 80)
            .readableColumn()
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) { topBar.readableColumn() }
        .background(threads.app.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editing) {
            if let draft = AnchorRuleDraft(editing: rule) {
                NavigationStack { AnchorFormScreen(draft: draft, editing: rule) }
            } else if let draft = PrayerRuleDraft(editing: rule) {
                NavigationStack { PrayerFormScreen(draft: draft, editing: rule) }
            }
        }
        .sheet(isPresented: $excepting) { ExceptionSheet(rule: rule, today: today) }
    }

    // MARK: Pieces

    private func summary(_ row: AnchorsOverview.Row?) -> String {
        if let row, let state = AnchorsCopy.state(row.state) { return state }
        guard let scheduled else { return prayer.map(AnchorsCopy.prayerLine) ?? "" }
        return AnchorsCopy.scheduleLine(scheduled, next: row?.next, today: today, style: style)
    }

    private var topBar: some View {
        HStack {
            if !embedded {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                        .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            Spacer()
            Menu {
                if breaks != nil { Button("Edit rule…") { if requireAccess(.editAnchorRule) { editing = true } } }
                if breaks != nil { Button("Pause…") { if requireAccess(.editAnchorRule) { excepting = true } } }
                Button("Archive", role: .destructive) {
                    guard requireAccess(.archiveOrRestore) else { return }
                    rule.isArchived = true
                    AppEngine.syncAnchors(in: context)
                    closeOrPop()
                }
            } label: {
                HStack(spacing: 6) { Text("Edit").threadsType(.row); Image(systemName: "chevron.down").font(.footnote) }
                    .foregroundStyle(threads.ink).padding(.horizontal, 20).frame(height: 48)
                    .glassEffect(.regular.interactive(), in: Capsule()).contentShape(Capsule())
            }
            .accessibilityIdentifier("ruleMenu")
        }
        .padding(.horizontal, ThreadsSpace.row)
        .padding(.top, ThreadsSpace.hair)
    }

    private func exceptions(_ list: [AnchorException]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Exceptions").threadsType(.label).foregroundStyle(threads.ink2).padding(.bottom, ThreadsSpace.tight)
            Divider().overlay(threads.line)
            ForEach(Array(list.enumerated()), id: \.offset) { index, exception in
                HStack {
                    Text(AnchorsCopy.exception(exception)).threadsType(.lede).foregroundStyle(threads.ink)
                    Spacer()
                    Button("Remove") {
                        guard requireAccess(.editAnchorRule) else { return }
                        try? AnchorEditing.removeException(from: rule, at: index)
                        AppEngine.syncAnchors(in: context)
                    }
                    .threadsType(.body).foregroundStyle(threads.ink2).buttonStyle(.plain)
                    .frame(minHeight: ThreadsHit.minimum)
                    .accessibilityLabel("Remove \(AnchorsCopy.exception(exception))")
                }
                .frame(minHeight: 52)
                Divider().overlay(threads.line)
            }
            Button { if requireAccess(.editAnchorRule) { excepting = true } } label: {
                Label("Add a break", systemImage: "plus").threadsType(.lede).foregroundStyle(threads.ink)
                    .frame(minHeight: 52, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addException")
            Divider().overlay(threads.line)
        }
    }

    @ViewBuilder private var upcoming: some View {
        let days = AnchorsOverview.upcoming(rule, from: today, days: 14, boundary: boundary).filter { $0.windowEnd > now }
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text("Coming up").threadsType(.label).foregroundStyle(threads.ink2)
            if days.isEmpty {
                Text("Nothing in the next two weeks.").threadsType(.lede).foregroundStyle(threads.ink2)
            }
            ForEach(Array(days.prefix(8).enumerated()), id: \.offset) { _, anchor in
                HStack {
                    Text(anchor.title).threadsType(.lede).foregroundStyle(threads.ink)
                    Spacer()
                    Text(AnchorsCopy.upcoming(anchor, today: today, style: style)).threadsType(.body).foregroundStyle(threads.ink2)
                }
                .frame(minHeight: 40)
            }
        }
        .accessibilityIdentifier("comingUp")
    }
}

/// A break (AN-06) or, from the detail's Pause, a pause: a range the rule skips, with a reason. Pending Anchors inside
/// it go; ones already decided stay.
struct ExceptionSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let rule: AnchorRule
    let today: CalendarDate
    @State private var reason: ExceptionReason = .holiday
    @State private var from: Date
    @State private var untilResumed = false
    @State private var until: Date
    @State private var message: String?

    init(rule: AnchorRule, today: CalendarDate) {
        self.rule = rule
        self.today = today
        _from = State(initialValue: today.pickerDate())
        _until = State(initialValue: today.addingDays(7).pickerDate())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("A BREAK").threadsType(.label).foregroundStyle(threads.ink2)
                    Text(rule.title).threadsType(.display(.compact)).foregroundStyle(threads.ink)
                    Text("It makes nothing on these days. Anything already decided stays.").threadsType(.lede).foregroundStyle(threads.ink2)
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("From").threadsType(.label).foregroundStyle(threads.ink2)
                    DatePicker("From", selection: $from, in: today.pickerDate()..., displayedComponents: .date).labelsHidden()
                    Text("Until").threadsType(.label).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.tight)
                    FlowChips {
                        Chip(title: "A date", isSelected: !untilResumed) { untilResumed = false }
                        Chip(title: "I resume it", isSelected: untilResumed) { untilResumed = true }
                            .accessibilityIdentifier("exceptionOpenEnded")
                    }
                    if !untilResumed {
                        DatePicker("Until", selection: $until, in: from..., displayedComponents: .date).labelsHidden()
                    }
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Why").threadsType(.label).foregroundStyle(threads.ink2)
                    FlowChips {
                        ForEach([ExceptionReason.term, .holiday, .travel, .illness, .other], id: \.self) { item in
                            Chip(title: AnchorsCopy.reasonTitle(item), isSelected: reason == item) { reason = item }
                        }
                    }
                }
                if let message { Text(message).threadsType(.body).foregroundStyle(threads.terra) }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
            .padding(.top, ThreadsSpace.section)
            .padding(.bottom, 100)
        }
        .background(threads.app)
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                Text("Add the break").threadsType(.row).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, ThreadsSpace.gutter).padding(.vertical, ThreadsSpace.tight)
            .background(threads.app)
            .accessibilityIdentifier("exceptionSave")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        do {
            try AnchorEditing.addException(
                to: rule, from: CalendarDate(pickerDate: from), to: untilResumed ? nil : CalendarDate(pickerDate: until), reason: reason)
            AppEngine.syncAnchors(in: context)
            dismiss()
        } catch let error as AnchorEditError {
            message = AnchorsCopy.message(for: error)
        } catch {
            message = "That couldn't be saved. Try again."
        }
    }
}
