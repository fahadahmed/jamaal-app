//
//  NotificationsScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Notifications and times (ST-03): the warning card when reminders can't arrive, this device's switch, the evening
/// planning and morning times (shared across devices), and where habit reminders are set.
struct NotificationsScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ReminderCenter.self) private var reminders
    @Query(sort: \UserSettings.createdAt) private var rows: [UserSettings]
    @Query private var rules: [AnchorRule]
    @Query private var habits: [Habit]

    private var device: String { ReminderCenter.deviceName }

    var body: some View {
        // Re-read the card's lines when a rule or habit changes.
        let _ = (rules.map { [$0.title, $0.configData, $0.isArchived ? "1" : "0"] }, habits.map { [$0.title, $0.isArchived ? "1" : "0"] })
        SettingsPage(title: "Notifications and times") {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                if reminders.isBlocked { warningCard }
                VStack(alignment: .leading, spacing: 0) {
                    Toggle(isOn: Binding(get: { reminders.remindersOnThisDevice }, set: { setSwitch($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send reminders on this \(device)").threadsType(.lede).foregroundStyle(threads.ink)
                            Text("Only this device").threadsType(.meta).foregroundStyle(threads.ink2)
                        }
                    }
                    .tint(threads.accent)
                    .frame(minHeight: 64).accessibilityIdentifier("remindersSwitch")
                    Divider().overlay(threads.line)
                    if let settings = rows.first {
                        timeRow("Evening planning", settings.planningMinute, id: "planningTime") { settings.planningMinute = $0 }
                        morningRow(settings)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Habit reminders").threadsType(.lede).foregroundStyle(threads.ink)
                        Text(ReminderCopy.habitRow(blocked: reminders.isBlocked)).threadsType(.meta).foregroundStyle(threads.ink2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
                }
                Text(ReminderCopy.footer).threadsType(.body).foregroundStyle(threads.ink2)
                #if DEBUG
                Text("scheduled \(reminders.scheduledCount)").threadsType(.meta).foregroundStyle(threads.ink3)
                    .accessibilityIdentifier("debugScheduled")
                #endif
            }
        }
        .task { await reminders.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reminders.refresh() } } }
    }

    // MARK: Pieces

    private var warningCard: some View {
        let lines = (try? ReminderStatus.undelivered(in: context, morningEnabled: reminders.morningEnabled)) ?? []
        return VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            Text(ReminderCopy.warningTitle(permission: reminders.permission, device: device)).threadsType(.lede).foregroundStyle(threads.ink)
            VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                ForEach(lines, id: \.self) { line in
                    Text("· \(line)").threadsType(.body).foregroundStyle(threads.ink)
                }
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier("undelivered")
            Button {
                if reminders.permission == .notAsked { Task { await reminders.requestPermission(); reminders.scheduleReplan(in: context) } }
                else { reminders.openSystemSettings() }
            } label: {
                Text(ReminderCopy.warningButton(reminders.permission, device: device)).threadsType(.row).foregroundStyle(threads.ink)
                    .frame(maxWidth: .infinity, minHeight: 52).overlay(Capsule().strokeBorder(threads.ink, lineWidth: 1)).contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("warningButton")
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card).strokeBorder(threads.line2, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("warningCard")
    }

    private func timeRow(_ title: String, _ minute: Int, id: String, set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title).threadsType(.lede).foregroundStyle(threads.ink)
            Spacer()
            DatePicker(title, selection: Binding(get: { HabitForm.date(forMinute: minute) }, set: { set(HabitForm.minute(of: $0)); reminders.scheduleReplan(in: context) }),
                       displayedComponents: .hourAndMinute)
                .labelsHidden().accessibilityIdentifier(id)
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
    }

    private func morningRow(_ settings: UserSettings) -> some View {
        HStack {
            Text("Morning list").threadsType(.lede).foregroundStyle(threads.ink)
            Spacer()
            if reminders.morningEnabled {
                DatePicker("Morning list", selection: Binding(get: { HabitForm.date(forMinute: settings.morningMinute) },
                                                              set: { settings.morningMinute = HabitForm.minute(of: $0); reminders.scheduleReplan(in: context) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden().accessibilityIdentifier("morningTime")
            }
            Toggle("Morning list", isOn: Binding(get: { reminders.morningEnabled }, set: { reminders.morningEnabled = $0; reminders.scheduleReplan(in: context) }))
                .labelsHidden().tint(threads.accent).accessibilityIdentifier("morningSwitch")
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Divider().overlay(threads.line) }
    }

    /// Turning the switch on asks for permission in context if it hasn't been asked.
    private func setSwitch(_ on: Bool) {
        reminders.remindersOnThisDevice = on
        Task {
            await reminders.refresh()
            if on, reminders.permission == .notAsked { await reminders.requestPermission() }
            reminders.scheduleReplan(in: context)
        }
    }
}

/// The one quiet line under a reminder that is set but can't arrive (docs G-77), with the way to fix it.
struct RemindersOffLine: View {
    @Environment(\.threads) private var threads
    @Environment(ReminderCenter.self) private var reminders

    var body: some View {
        if reminders.isBlocked {
            HStack(alignment: .firstTextBaseline, spacing: ThreadsSpace.tight) {
                Text(ReminderCopy.quietLine).threadsType(.meta).foregroundStyle(threads.ink2)
                Button(reminders.permission == .notAsked ? "Turn on" : "Open Settings") {
                    if reminders.permission == .notAsked { Task { await reminders.requestPermission() } } else { reminders.openSystemSettings() }
                }
                .threadsType(.meta).foregroundStyle(threads.ink).buttonStyle(.plain).frame(minHeight: ThreadsHit.minimum)
            }
            .accessibilityIdentifier("remindersOffLine")
        }
    }
}
