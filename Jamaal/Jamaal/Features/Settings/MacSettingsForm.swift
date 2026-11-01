//
//  MacSettingsForm.swift
//  Jamaal
//

#if os(macOS)
import SwiftUI
import ThreadsTokens

/// What the Mac Settings panes share (#367): a grouped form on the app's ground, tinted with the palette's accent, whose controls are the
/// system's at their regular size, and rows labelled in the design's type (`docs/design/mac-settings-window.md`).
private struct MacSettingsFormStyle: ViewModifier {
    @Environment(\.threads) private var threads

    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(threads.app)
            .tint(threads.accent)
    }
}

extension View {
    /// The Mac Settings pane's form: grouped, on the app ground, in the accent.
    func macSettingsForm() -> some View { modifier(MacSettingsFormStyle()) }
}

/// A form row's label: the title in the body type, and an optional line under it in the meta type.
struct MacRowLabel: View {
    @Environment(\.threads) private var threads
    let title: String
    var note: String?

    init(_ title: String, note: String? = nil) { self.title = title; self.note = note }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).threadsType(.body).foregroundStyle(threads.ink)
            if let note { Text(note).threadsType(.meta).foregroundStyle(threads.ink2).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

/// A form section's header, in the label type the iPhone uses for the same headings.
struct MacSectionHeader: View {
    @Environment(\.threads) private var threads
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View { Text(title.uppercased()).threadsType(.label).foregroundStyle(threads.ink2) }
}

/// A line of explanation or an error under a form section.
struct MacFormNote: View {
    @Environment(\.threads) private var threads
    let text: String
    var isError = false

    init(_ text: String, isError: Bool = false) { self.text = text; self.isError = isError }

    var body: some View {
        Text(text).threadsType(.body).foregroundStyle(isError ? threads.terra : threads.ink2).fixedSize(horizontal: false, vertical: true)
    }
}
#endif
