//
//  AddMinutesSheet.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// Minutes by hand (HB-09): a timed habit's minutes added without the timer, for today or a day in the last 14. They are
/// finished manual sessions that feed the same total, and one can be taken back out. Living the day, so never locked.
struct AddMinutesSheet: View {
    @Environment(\.threads) private var threads
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let window: HabitTimeWindow
    @State private var day: CalendarDate
    @State private var minutes = HabitMinutes.defaultMinutes
    @State private var message: String?
    @State private var refresh = 0

    init(habit: Habit, window: HabitTimeWindow, day: CalendarDate) {
        self.habit = habit
        self.window = window
        _day = State(initialValue: day)
    }

    private var boundary: DayBoundary { TodayDay.boundary(in: context) }
    private var today: CalendarDate { boundary.logicalDate(at: .now) }

    var body: some View {
        _ = refresh
        let progress = HabitMinutes.progress(of: window, on: day)
        let earlier = HabitMinutes.manualSessions(of: window, on: day)
        return ScrollView {
            VStack(alignment: .leading, spacing: ThreadsSpace.section) {
                VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
                    Text("Add minutes").threadsType(.display(.compact)).foregroundStyle(threads.ink).accessibilityAddTraits(.isHeader)
                    Text(HabitMinutesCopy.subtitle(habit: habit.title, day: day, today: today, done: progress.done, target: progress.target))
                        .threadsType(.lede).foregroundStyle(threads.ink2).accessibilityIdentifier("addMinutesSubtitle")
                }
                HStack(spacing: ThreadsSpace.section) {
                    Spacer()
                    round("minus", "Fewer minutes", id: "minutesLess", enabled: minutes > HabitMinutes.range.lowerBound) {
                        minutes = max(HabitMinutes.range.lowerBound, minutes - HabitMinutes.step)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        ThreadsNumeral("\(minutes)", size: .large).foregroundStyle(threads.ink)
                        Text("min").threadsType(.lede).foregroundStyle(threads.ink2)
                    }
                    .frame(minWidth: 130).accessibilityElement(children: .combine)
                    .accessibilityLabel("\(minutes) minutes").accessibilityIdentifier("minutesValue")
                    round("plus", "More minutes", id: "minutesMore", enabled: minutes < HabitMinutes.range.upperBound) {
                        minutes = min(HabitMinutes.range.upperBound, minutes + HabitMinutes.step)
                    }
                    Spacer()
                }
                VStack(spacing: 0) {
                    Divider().overlay(threads.line)
                    HStack {
                        Text("Day").threadsType(.lede).foregroundStyle(threads.ink2)
                        Spacer()
                        DatePicker("Day", selection: Binding(get: { day.pickerDate() }, set: { day = CalendarDate(pickerDate: $0) }),
                                   in: earliest.pickerDate()...today.pickerDate(), displayedComponents: .date)
                            .labelsHidden().accessibilityIdentifier("minutesDay")
                    }
                    .frame(minHeight: 60)
                    Divider().overlay(threads.line)
                }
                if let message { Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("addMinutesMessage") }
                Button(action: add) {
                    Text(HabitMinutesCopy.button(minutes)).threadsType(.row).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(threads.terra)).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityIdentifier("addMinutesButton")
                if !earlier.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ADDED BY HAND").threadsType(.label).foregroundStyle(threads.ink2).padding(.bottom, ThreadsSpace.tight)
                        ForEach(earlier, id: \.id) { session in
                            HStack {
                                Text(HabitMinutesCopy.sessionLine(minutes: session.actualSeconds / 60, at: session.startedAt, timeZone: boundary.timeZone))
                                    .threadsType(.lede).foregroundStyle(threads.ink)
                                Spacer()
                                Button("Remove") { remove(session) }.threadsType(.row).foregroundStyle(threads.ink2).buttonStyle(.plain)
                                    .frame(minHeight: ThreadsHit.minimum)
                                    .accessibilityLabel("Remove \(session.actualSeconds / 60) minutes").accessibilityIdentifier("removeMinutes")
                            }
                            .frame(minHeight: 52)
                            Divider().overlay(threads.line)
                        }
                    }
                }
            }
            .padding(.horizontal, ThreadsSpace.gutter).padding(.top, ThreadsSpace.section).padding(.bottom, 40)
        }
        .background(threads.app)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// The earliest day open for correction: 13 days back, and never before the habit existed.
    private var earliest: CalendarDate { max(today.addingDays(-13), boundary.logicalDate(at: habit.createdAt)) }

    private func round(_ symbol: String, _ label: String, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3).foregroundStyle(threads.ink).frame(width: 56, height: 56)
                .background(Circle().fill(threads.card)).overlay(Circle().strokeBorder(threads.line2, lineWidth: 1)).contentShape(Circle())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(label).accessibilityIdentifier(id)
    }

    private func add() {
        do {
            try HabitMinutes.add(minutes, to: window, on: day, now: .now, boundary: boundary, context: context)
            dismiss()
        } catch let error as HabitMinutesError {
            message = HabitMinutesCopy.message(for: error)
        } catch {
            message = "That couldn't be saved. Try again."
        }
    }

    private func remove(_ session: WorkSession) {
        HabitMinutes.remove(session, now: .now, context: context)
        refresh += 1
    }
}
