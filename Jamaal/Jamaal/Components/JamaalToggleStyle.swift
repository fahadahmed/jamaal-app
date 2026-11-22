//
//  JamaalToggleStyle.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// The app's switch (#422). The system switch puts a **white** thumb on the tinted track, and the accent in dark mode is a pale mint, so
/// the thumb was 1.8:1 against it: the state was hard to see. Here the thumb takes `onAccent` (dark on the pale track in dark mode, light on
/// the deep track in light mode), about 6:1 either way, and the off state is an outlined track with an `ink3` thumb (5:1 on the page).
/// It is still a switch to VoiceOver and to UI tests: the accessibility representation is a plain `Toggle`.
struct JamaalToggleStyle: ToggleStyle {
    @Environment(\.threads) private var threads
    @Environment(\.isEnabled) private var isEnabled

    /// Only the switch, for a row that draws its own label beside it (what `.labelsHidden()` did for the system switch; a custom style
    /// draws whatever it likes, so it has to be a style of its own).
    var showsLabel = true

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: ThreadsSpace.row) {
                if showsLabel {
                    configuration.label
                    Spacer(minLength: ThreadsSpace.tight)
                }
                track(isOn: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }

    private func track(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? threads.accent : Color.clear)
            Capsule().strokeBorder(isOn ? threads.accent : threads.ink3, lineWidth: 1.5)
            Circle().fill(isOn ? threads.onAccent : threads.ink3).padding(4)
        }
        .frame(width: 52, height: 32)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}

extension View {
    /// A switch with no label of its own: `.labelsHidden()` on the Mac, where the system switch is kept, and the Jamaal switch alone on iOS.
    func switchOnly() -> some View {
        #if os(iOS)
        toggleStyle(JamaalToggleStyle(showsLabel: false))
        #else
        labelsHidden()
        #endif
    }
}
