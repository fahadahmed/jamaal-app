//
//  CapacityAndDayScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Capacity and day (ST-02): the normal day, each weekday's usual level, the working day, and the rollover.
struct CapacityAndDayScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Query(sort: \UserSettings.createdAt) private var rows: [UserSettings]
    @State private var message: String?
    @State private var suggestion: Int?

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }

    var body: some View {
        SettingsPage(title: "Capacity and day") {
            if let settings = rows.first { content(settings) }
        }
        .task(id: rows.first?.mediumDayMinutes) { refreshSuggestion() }
    }

    @ViewBuilder
    private func content(_ settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.section) {
            normalDay(settings)
            weekdays(settings)
            workingDay(settings)
            advanced(settings)
            if let message {
                Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("settingsMessage")
            }
        }
    }

    // MARK: Sections

    private func normalDay(_ settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Normal day").threadsType(.lede).foregroundStyle(threads.ink)
                    Text("Task time on a medium day").threadsType(.meta).foregroundStyle(threads.ink2)
                }
                Spacer()
                Text(TodayCopy.duration(settings.mediumDayMinutes)).threadsType(.lede).foregroundStyle(threads.ink)
                    .accessibilityIdentifier("normalDay")
                StepperPill(title: "normal day",
                            canDecrement: settings.mediumDayMinutes > DaySettings.normalDayRange.lowerBound,
                            onDecrement: { stepNormalDay(settings, by: -1) }, onIncrement: { stepNormalDay(settings, by: 1) })
                    .scaleEffect(0.85)
            }
            if let suggestion {
                HStack(alignment: .firstTextBaseline) {
                    Text(SettingsCopy.suggestion(suggestion)).threadsType(.body).foregroundStyle(threads.ink2)
                    Spacer(minLength: ThreadsSpace.tight)
                    VStack(alignment: .trailing, spacing: 0) {
                        Button("Set \(TodayCopy.duration(suggestion))") { accept(suggestion, settings) }
                            .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                            .frame(minHeight: ThreadsHit.minimum).accessibilityIdentifier("setSuggestion")
                        Button("Not now") { decline(suggestion) }
                            .threadsType(.meta).foregroundStyle(threads.ink2).buttonStyle(.plain)
                            .frame(minHeight: ThreadsHit.minimum).accessibilityIdentifier("declineSuggestion")
                    }
                }
            }
            Text(SettingsCopy.levels(mediumDayMinutes: settings.mediumDayMinutes)).threadsType(.body).foregroundStyle(threads.ink2)
                .accessibilityIdentifier("levels")
        }
    }

    private func weekdays(_ settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("USUAL LEVEL BY WEEKDAY").threadsType(.label).foregroundStyle(threads.ink2).padding(.bottom, ThreadsSpace.tight)
            Divider().overlay(threads.line)
            ForEach(1...7, id: \.self) { day in
                HStack {
                    Text(SettingsCopy.weekdays[day - 1]).threadsType(.lede).foregroundStyle(threads.ink)
                    Spacer()
                    Picker(SettingsCopy.weekdays[day - 1], selection: Binding(
                        get: { settings.defaultLevel(forISOWeekday: day) },
                        set: { settings.setDefaultLevel($0, forISOWeekday: day) })) {
                        Text("Low").tag(CapacityLevel.low)
                        Text("Med").tag(CapacityLevel.medium)
                        Text("High").tag(CapacityLevel.high)
                    }
                    .pickerStyle(.segmented).frame(width: 210)
                    .accessibilityIdentifier("level-\(day)")
                }
                .frame(minHeight: 56)
                Divider().overlay(threads.line)
            }
        }
    }

    private func workingDay(_ settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WORKING DAY").threadsType(.label).foregroundStyle(threads.ink2).padding(.bottom, ThreadsSpace.tight)
            Divider().overlay(threads.line)
            timeRow("Starts", settings.dayStartMinute, id: "dayStart") { setDay(settings, start: $0, end: settings.dayEndMinute) }
            timeRow("Ends", settings.dayEndMinute, id: "dayEnd") { setDay(settings, start: settings.dayStartMinute, end: $0) }
            if let planning = DaySettings.planningBeforeDayEnd(settings) {
                Text(SettingsCopy.planningNote(planningMinute: planning)).threadsType(.body).foregroundStyle(threads.ink2)
                    .padding(.top, ThreadsSpace.row).accessibilityIdentifier("planningNote")
            }
        }
    }

    private func timeRow(_ title: String, _ minute: Int, id: String, set: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink)
                Spacer()
                DatePicker(title, selection: Binding(get: { HabitForm.date(forMinute: minute) }, set: { set(HabitForm.minute(of: $0)) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden().accessibilityIdentifier(id)
            }
            .frame(minHeight: 56)
            Divider().overlay(threads.line)
        }
    }

    private func advanced(_ settings: UserSettings) -> some View {
        let now = SettingsCopy.minuteOfDay(.now, timeZone: boundary.timeZone)
        let availability = DaySettings.rolloverAvailability(settings, nowMinute: now)
        let options = SettingsCopy.rolloverOptions(availability)
        let enabled: Bool = { if case .upTo = availability { true } else { false } }()
        return VStack(alignment: .leading, spacing: 0) {
            Text("ADVANCED").threadsType(.label).foregroundStyle(threads.ink2).padding(.bottom, ThreadsSpace.tight)
            Divider().overlay(threads.line)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A new day starts at").threadsType(.lede).foregroundStyle(threads.ink)
                    Text(SettingsCopy.rolloverNote(availability)).threadsType(.meta).foregroundStyle(threads.ink2)
                }
                Spacer()
                Menu {
                    ForEach(options, id: \.minute) { option in
                        Button(PlanningCopy.clock(option.minute)) { setRollover(settings, option.minute, now: now) }.disabled(!option.enabled)
                    }
                } label: {
                    Text(PlanningCopy.clock(settings.rolloverMinute)).threadsType(.lede).foregroundStyle(enabled ? threads.ink : threads.ink3)
                        .frame(minHeight: ThreadsHit.minimum).contentShape(Rectangle())
                }
                .disabled(!enabled)
                .accessibilityIdentifier("rollover")
            }
            .frame(minHeight: 64)
            Divider().overlay(threads.line)
        }
    }

    // MARK: Changes

    private func stepNormalDay(_ settings: UserSettings, by steps: Int) {
        run { try DaySettings.setNormalDay(settings.mediumDayMinutes + steps * DaySettings.normalDayStep, on: settings) }
    }

    private func setDay(_ settings: UserSettings, start: Int, end: Int) {
        run { try DaySettings.setWorkingDay(start: start, end: end, on: settings) }
    }

    private func setRollover(_ settings: UserSettings, _ minute: Int, now: Int) {
        run { try DaySettings.setRollover(minute, on: settings, nowMinute: now) }
    }

    private func accept(_ minutes: Int, _ settings: UserSettings) {
        run { try DaySettings.setNormalDay(minutes, on: settings) }
        suggestion = nil
    }

    private func decline(_ minutes: Int) {
        try? DaySettings.decline(minutes, in: context, now: .now)
        suggestion = nil
    }

    private func run(_ change: () throws -> Void) {
        do { try change(); message = nil }
        catch let error as SettingsError { message = SettingsCopy.message(for: error) }
        catch { message = "That couldn't be saved. Try again." }
    }

    private func refreshSuggestion() {
        guard let settings = rows.first else { return }
        let today = boundary.logicalDate(at: .now)
        suggestion = try? DaySettings.normalDaySuggestion(in: context, settings: settings, today: today)
        if let suggestion { try? DaySettings.logShown(suggestion, in: context, now: .now) }
    }
}
