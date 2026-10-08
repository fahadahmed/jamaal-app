//
//  PrayerFormScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The prayer times form (AN-04). Asks where first (AN-11), since nothing can be worked out without a place.
struct PrayerFormScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let rule: AnchorRule?
    private let onFinished: () -> Void
    private let finder: any PlaceFinding
    @State private var form: PrayerForm
    @State private var message: String?
    @State private var choosingPlace: Bool
    @State private var searching = false
    @State private var showingMethods = false
    @State private var showingAdvanced = false
    @State private var working = false
    @State private var notice: String?

    init(draft: PrayerRuleDraft, editing rule: AnchorRule?, onFinished: @escaping () -> Void = {}) {
        self.rule = rule
        self.onFinished = onFinished
        finder = PlaceFinders.make()
        let country = Locale.current.region?.identifier
        _form = State(initialValue: rule == nil ? PrayerForm.new(deviceCountry: country) : PrayerForm(draft: draft, deviceCountry: country))
        _choosingPlace = State(initialValue: rule == nil)
    }

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                row("Title") {
                    TextField("Salah", text: $form.draft.title).multilineTextAlignment(.trailing)
                        .threadsType(.lede).foregroundStyle(threads.ink).accessibilityLabel("Name").accessibilityIdentifier("anchorName")
                }
                Button { choosingPlace = true } label: {
                    row("Location") {
                        HStack(spacing: 6) {
                            Text(form.locationLine()).threadsType(.lede).foregroundStyle(threads.ink)
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
                        }
                    }
                }
                .buttonStyle(.plain).accessibilityIdentifier("prayerLocation")
                Button { showingMethods = true } label: {
                    row("Method") {
                        HStack(spacing: 6) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(PrayerMethods.title(for: form.draft.method)).threadsType(.lede).foregroundStyle(threads.ink)
                                if let line = form.suggestionLine() { Text(line).threadsType(.meta).foregroundStyle(threads.ink2) }
                            }
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
                        }
                    }
                }
                .buttonStyle(.plain).accessibilityIdentifier("prayerMethod")
                row("Asr") {
                    Picker("Asr", selection: $form.draft.madhab) {
                        Text("Standard").tag("shafi")
                        Text("Hanafi").tag("hanafi")
                    }
                    .pickerStyle(.segmented).frame(width: 200)
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Prayers").threadsType(.label).foregroundStyle(threads.ink2)
                    FlowChips {
                        ForEach(["fajr", "dhuhr", "asr", "maghrib", "isha"], id: \.self) { prayer in
                            Chip(title: PrayerForm.name(prayer), isSelected: form.isOn(prayer)) { form.togglePrayer(prayer) }
                                .accessibilityIdentifier("prayer-\(prayer)")
                        }
                    }
                }
                .padding(.vertical, ThreadsSpace.section)
                Divider().overlay(threads.line)
                row("Isha ends") {
                    Menu {
                        Button("Islamic midnight") { form.draft.ishaEnds = "midnight" }
                        Button("Fajr") { form.draft.ishaEnds = "fajr" }
                    } label: {
                        Text(PrayerForm.ishaEndsTitle(form.draft.ishaEnds)).threadsType(.lede).foregroundStyle(threads.ink)
                    }
                    .accessibilityIdentifier("ishaEnds")
                }
                VStack(spacing: 0) {
                    Toggle(isOn: $form.draft.fridayLabel) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Call Friday's Dhuhr Jumu'ah").threadsType(.lede).foregroundStyle(threads.ink)
                            Text("Same time, only the name").threadsType(.meta).foregroundStyle(threads.ink2)
                        }
                    }
                    .padding(.vertical, ThreadsSpace.tight).accessibilityIdentifier("fridayLabel")
                    Divider().overlay(threads.line)
                }
                row("Time each takes") {
                    HStack {
                        Text(form.draft.effortMinutes.map { "\($0) min" } ?? "Not set").threadsType(.lede).foregroundStyle(threads.ink)
                        Stepper("", value: Binding(get: { form.draft.effortMinutes ?? 0 }, set: { form.draft.effortMinutes = $0 > 0 ? $0 : nil }), in: 0...120, step: 5)
                            .labelsHidden()
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    row("Remind me") {
                        Text(AnchorForm.reminderSummary(atStart: form.draft.remindAtStart, beforeEnd: form.draft.remindBeforeEndMinutes))
                            .threadsType(.lede).foregroundStyle(threads.ink)
                    }
                    Toggle("At the start", isOn: $form.draft.remindAtStart).threadsType(.lede).foregroundStyle(threads.ink)
                    Toggle("Shortly before it closes", isOn: Binding(
                        get: { form.draft.remindBeforeEndMinutes != nil },
                        set: { form.draft.remindBeforeEndMinutes = $0 ? 10 : nil })).threadsType(.lede).foregroundStyle(threads.ink)
                        .padding(.bottom, ThreadsSpace.tight)
                    if form.draft.remindAtStart || form.draft.remindBeforeEndMinutes != nil { RemindersOffLine().padding(.bottom, ThreadsSpace.tight) }
                    Divider().overlay(threads.line)
                }
                Button { showingAdvanced = true } label: {
                    row("Advanced", labelInk: threads.ink) {
                        HStack(spacing: 6) {
                            Text(form.advancedSummary).threadsType(.body).foregroundStyle(threads.ink2)
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(threads.ink3)
                        }
                    }
                }
                .buttonStyle(.plain).accessibilityIdentifier("prayerAdvanced")
                if let note = form.footnote(now: .now, boundary: boundary) {
                    Text(note).threadsType(.body).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.section)
                        .accessibilityIdentifier("prayerFootnote")
                }
                if let notice { Text(notice).threadsType(.body).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.tight) }
                if let message {
                    Text(message).threadsType(.body).foregroundStyle(threads.terra).padding(.top, ThreadsSpace.tight)
                        .accessibilityIdentifier("anchorFormMessage")
                }
                Button(action: save) {
                    Text("Save").threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
                }
                .buttonStyle(.plain).padding(.top, ThreadsSpace.section).accessibilityIdentifier("saveAnchorRule")
            }
            .padding(.horizontal, ThreadsSpace.gutter).padding(.bottom, 60)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(threads.app)
        .navigationTitle("Prayer times")
        .inlineNavigationTitle()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .sheet(isPresented: $choosingPlace) {
            WhereSheet(finder: finder, working: $working, notice: $notice,
                       onPlace: { place, mode in form.choose(place, mode: mode); choosingPlace = false },
                       onCity: { choosingPlace = false; searching = true })
        }
        .navigationDestination(isPresented: $searching) {
            CitySearchScreen(finder: finder) { place in form.choose(place, mode: "manual"); searching = false }
        }
        .navigationDestination(isPresented: $showingMethods) {
            MethodListScreen(selected: form.draft.method, suggestion: form.suggestionLine()) { key in
                form.chooseMethod(key); showingMethods = false
            }
        }
        .navigationDestination(isPresented: $showingAdvanced) { PrayerAdvancedScreen(form: $form) }
    }

    private func row<Value: View>(_ title: String, labelInk: Color? = nil, @ViewBuilder value: () -> Value) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title).threadsType(.lede).foregroundStyle(labelInk ?? threads.ink2)
                Spacer(minLength: ThreadsSpace.tight)
                value()
            }
            .frame(minHeight: 56).contentShape(Rectangle())
            Divider().overlay(threads.line)
        }
    }

    private func save() {
        do {
            if let rule { try PrayerEditing.update(rule, with: form.draft) }
            else { try PrayerEditing.create(form.draft, in: context, now: .now) }
            AppEngine.syncAnchors(in: context)
            onFinished()
            dismiss()
        } catch let error as PrayerEditError {
            message = PrayerForm.message(for: error)
        } catch {
            message = "That couldn't be saved. Try again."
        }
    }
}

/// "Where are you praying?" (AN-11): use the device's location, asked for only now, or choose a city.
private struct WhereSheet: View {
    @Environment(\.threads) private var threads
    let finder: any PlaceFinding
    @Binding var working: Bool
    @Binding var notice: String?
    let onPlace: (FoundPlace, String) -> Void
    let onCity: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            Text("Where are you praying?").threadsType(.display(.compact)).foregroundStyle(threads.ink)
            Text("Prayer times depend on where you are. Jamaal checks your location only while it's open, and updates the times if you travel.")
                .threadsType(.lede).foregroundStyle(threads.ink2)
            VStack(spacing: ThreadsSpace.tight) {
                Button {
                    Task {
                        working = true
                        if let place = await finder.current() { notice = nil; onPlace(place, "device") }
                        else { notice = "Jamaal couldn't find where you are. Choose a city instead." }
                        working = false
                    }
                } label: {
                    Label(working ? "Finding you…" : "Use my location", systemImage: "location")
                        .threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
                }
                .buttonStyle(.plain).disabled(working).accessibilityIdentifier("useMyLocation")
                Button(action: onCity) {
                    Text("Choose a city").threadsType(.row).foregroundStyle(threads.ink)
                        .frame(maxWidth: .infinity, minHeight: 56).overlay(Capsule().strokeBorder(threads.line2)).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityIdentifier("chooseACity")
            }
            if let notice { Text(notice).threadsType(.body).foregroundStyle(threads.ink2) }
        }
        .padding(ThreadsSpace.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(threads.app)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}

/// A city search (AN-11): needs a connection; a city is kept as the rule's place until changed.
private struct CitySearchScreen: View {
    @Environment(\.threads) private var threads
    let finder: any PlaceFinding
    let onPick: (FoundPlace) -> Void
    @State private var query = ""
    @State private var results: [FoundPlace] = []
    @State private var searched = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, place in
                    Button { onPick(place) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name).threadsType(.row).foregroundStyle(threads.ink)
                            Text(place.detail).threadsType(.body).foregroundStyle(threads.ink2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("city-\(place.name)-\(place.countryCode ?? "")")
                    Divider().overlay(threads.line)
                }
                if searched && results.isEmpty {
                    Text("Nothing found. Check the spelling, or your connection.").threadsType(.body).foregroundStyle(threads.ink2)
                        .padding(.top, ThreadsSpace.section)
                }
                Text("Searching needs a connection. A city is kept as the rule's place until you change it.")
                    .threadsType(.body).foregroundStyle(threads.ink2).padding(.top, ThreadsSpace.section)
            }
            .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.row)
        }
        .background(threads.app)
        .navigationTitle("Choose a city")
        .inlineNavigationTitle()
        #if os(iOS)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a city")
        #else
        .searchable(text: $query, prompt: "Search for a city")
        #endif
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            results = await finder.search(query)
            searched = query.trimmingCharacters(in: .whitespaces).count >= 2
        }
    }
}

private struct MethodListScreen: View {
    @Environment(\.threads) private var threads
    let selected: String
    let suggestion: String?
    let onPick: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(PrayerMethods.all, id: \.key) { item in
                    Button { onPick(item.key) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).threadsType(.lede).foregroundStyle(threads.ink)
                                if item.key == selected, let suggestion { Text(suggestion).threadsType(.meta).foregroundStyle(threads.ink2) }
                            }
                            Spacer()
                            if item.key == selected { Image(systemName: "checkmark").foregroundStyle(threads.ink) }
                        }
                        .frame(minHeight: 56).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("method-\(item.key)")
                    .accessibilityAddTraits(item.key == selected ? .isSelected : [])
                    Divider().overlay(threads.line)
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter)
        }
        .background(threads.app)
        .navigationTitle("Method")
        .inlineNavigationTitle()
    }
}

/// Advanced (AN-04): a few minutes either way per prayer to match a local mosque timetable, and the high-latitude rule.
private struct PrayerAdvancedScreen: View {
    @Environment(\.threads) private var threads
    @Binding var form: PrayerForm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Adjustments").threadsType(.label).foregroundStyle(threads.ink2)
                    Text("To match your mosque's timetable, move a prayer's start a few minutes either way.")
                        .threadsType(.body).foregroundStyle(threads.ink2)
                    Divider().overlay(threads.line)
                    ForEach(["fajr", "dhuhr", "asr", "maghrib", "isha"], id: \.self) { prayer in
                        HStack {
                            Text(PrayerForm.name(prayer)).threadsType(.lede).foregroundStyle(threads.ink)
                            Spacer()
                            Text(PrayerForm.adjustment(form.draft.adjustments[prayer] ?? 0)).threadsType(.lede).foregroundStyle(threads.ink2)
                                .accessibilityIdentifier("adjustment-\(prayer)")
                            StepperPill(title: PrayerForm.name(prayer) + " adjustment", canDecrement: (form.draft.adjustments[prayer] ?? 0) > -60,
                                        onDecrement: { form.stepAdjustment(prayer, by: -1) }, onIncrement: { form.stepAdjustment(prayer, by: 1) })
                                .scaleEffect(0.85)
                        }
                        .frame(minHeight: 52)
                        Divider().overlay(threads.line)
                    }
                }
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Far from the equator").threadsType(.label).foregroundStyle(threads.ink2)
                    Text("In summer, far north or south, the sky may never get dark enough. This decides how Fajr and Isha are worked out then.")
                        .threadsType(.body).foregroundStyle(threads.ink2)
                    FlowChips {
                        ForEach(["middleOfNight", "seventhOfNight", "twilightAngle"], id: \.self) { key in
                            Chip(title: PrayerForm.highLatitudeTitle(key), isSelected: form.draft.highLatitude == key) { form.draft.highLatitude = key }
                                .accessibilityIdentifier("highLatitude-\(key)")
                        }
                    }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.row).padding(.bottom, 60)
        }
        .background(threads.app)
        .navigationTitle("Advanced")
        .inlineNavigationTitle()
    }
}
