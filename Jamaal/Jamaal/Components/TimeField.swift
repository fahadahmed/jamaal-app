//
//  TimeField.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A time of day, set with a wheel that opens **inline** in a solid card (#422). The system's compact time picker opens a see-through glass
/// popover whose wheel is faint, which in dark mode was hard to read. Here the wheel sits on `selected` (the page's card colour in each
/// scheme) with the system's primary label colour on it, so the numbers have full contrast in light and dark.
///
/// `TimeField` is the whole row: the label, the time as a pill, and the wheel beneath when the pill is open. A row that has more beside
/// the pill (the Morning list switch) uses `TimePill` and `TimeWheelCard` itself. On the Mac the system field stays: it is a field in a
/// form there, not a popover.
struct TimeField: View {
    let title: String
    @Binding var selection: Date
    var id: String
    @State private var isOpen = false
    @Environment(\.threads) private var threads

    init(_ title: String, selection: Binding<Date>, id: String) {
        self.title = title
        _selection = selection
        self.id = id
    }

    var body: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            HStack {
                Text(title).threadsType(.lede).foregroundStyle(threads.ink)
                Spacer()
                TimePill(title, selection: selection, isOpen: $isOpen, id: id)
            }
            .frame(minHeight: 56)
            if isOpen { TimeWheelCard(selection: $selection, id: id + "Wheel") }
        }
        .animation(.snappy(duration: 0.2), value: isOpen)
        #else
        HStack {
            Text(title).threadsType(.lede).foregroundStyle(threads.ink)
            Spacer()
            DatePicker(title, selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden().accessibilityIdentifier(id)
        }
        .frame(minHeight: 56)
        #endif
    }
}

#if os(iOS)
/// The time, as a button that opens and closes the wheel.
struct TimePill: View {
    let title: String
    let selection: Date
    @Binding var isOpen: Bool
    var id: String
    @Environment(\.threads) private var threads

    init(_ title: String, selection: Date, isOpen: Binding<Bool>, id: String) {
        self.title = title
        self.selection = selection
        _isOpen = isOpen
        self.id = id
    }

    var body: some View {
        Button { isOpen.toggle() } label: {
            Text(selection.formatted(date: .omitted, time: .shortened))
                .threadsType(.lede).foregroundStyle(isOpen ? threads.onAccent : threads.ink)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .background(Capsule().fill(isOpen ? threads.accent : threads.selected))
                .overlay(Capsule().strokeBorder(threads.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title).accessibilityValue(selection.formatted(date: .omitted, time: .shortened))
        .accessibilityHint(isOpen ? "Closes the time wheel" : "Opens a time wheel")
        .accessibilityIdentifier(id)
    }
}

/// The wheel on a solid card.
struct TimeWheelCard: View {
    @Binding var selection: Date
    var id: String
    @Environment(\.threads) private var threads

    var body: some View {
        DatePicker("Time", selection: $selection, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel).labelsHidden()
            .frame(maxWidth: .infinity).frame(height: 216)
            .clipShape(RoundedRectangle(cornerRadius: ThreadsRadius.card, style: .continuous))
            .background(RoundedRectangle(cornerRadius: ThreadsRadius.card, style: .continuous).fill(threads.selected))
            .overlay(RoundedRectangle(cornerRadius: ThreadsRadius.card, style: .continuous).strokeBorder(threads.line))
            .padding(.bottom, ThreadsSpace.row)
            .accessibilityIdentifier(id)
    }
}
#endif
