//
//  NoteEditorScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore

/// The note editor (TK-04): the note's markdown with a glass toolbar above the keyboard (checklist, bold, italic, link,
/// code). Return keeps a checklist going and ends it on an empty item. The note saves as it is written; Back and Done just
/// close. The formatting rules are the engine's (`NoteEditing`).
struct NoteEditorScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    @State private var text: String
    @State private var selection: TextSelection?
    @SwiftUI.FocusState private var focused: Bool

    init(task: TaskItem) {
        self.task = task
        _text = State(initialValue: task.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Text(task.title.uppercased()).threadsType(.label).foregroundStyle(threads.ink2).lineLimit(2)
                .padding(.horizontal, ThreadsSpace.gutter).padding(.top, 76)
            TextEditor(text: $text, selection: $selection)
                .threadsType(.lede).foregroundStyle(threads.ink)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(.horizontal, ThreadsSpace.gutter - 5)
                .accessibilityLabel("Note").accessibilityIdentifier("noteEditor")
        }
        .overlay(alignment: .top) { topBar }
        .safeAreaInset(edge: .bottom) { formatting }
        .background(threads.app.ignoresSafeArea())
        .onChange(of: text) { old, new in textChanged(from: old, to: new) }
        .onAppear { focused = true; placeCaretAtEnd() }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(threads.ink)
                    .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
            }
            .buttonStyle(.plain).accessibilityLabel("Back").accessibilityIdentifier("noteBack")
            Spacer()
            Text("Note").threadsType(.row).foregroundStyle(threads.ink)
            Spacer()
            Button { dismiss() } label: {
                Text("Done").threadsType(.row).foregroundStyle(threads.ink).padding(.horizontal, 22).frame(height: 48)
                    .glassEffect(.regular.interactive(), in: Capsule()).contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("noteDone")
        }
        .padding(.horizontal, ThreadsSpace.row).padding(.top, ThreadsSpace.hair)
    }

    private var formatting: some View {
        HStack {
            tool("checklist", "Checklist", id: "noteChecklist") { NoteEditing.toggleChecklist(text, selection: $0) }
            tool("bold", "Bold", id: "noteBold") { NoteEditing.bold(text, selection: $0) }
            tool("italic", "Italic", id: "noteItalic") { NoteEditing.italic(text, selection: $0) }
            tool("link", "Link", id: "noteLink") { NoteEditing.link(text, selection: $0) }
            tool("chevron.left.forwardslash.chevron.right", "Code", id: "noteCode") { NoteEditing.code(text, selection: $0) }
        }
        .padding(.horizontal, ThreadsSpace.row).frame(height: 56)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, ThreadsSpace.row).padding(.bottom, ThreadsSpace.tight)
    }

    private func tool(_ symbol: String, _ label: String, id: String, _ edit: @escaping (Range<Int>) -> NoteEdit) -> some View {
        Button { apply(edit(currentRange())) } label: {
            Image(systemName: symbol).font(.title3).foregroundStyle(threads.ink)
                .frame(maxWidth: .infinity, minHeight: ThreadsHit.minimum).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id)
    }

    // MARK: Editing

    /// The selection as character offsets (the end of the note when there is none yet).
    private func currentRange() -> Range<Int> {
        guard let selection, case .selection(let range) = selection.indices,
              range.lowerBound >= text.startIndex, range.upperBound <= text.endIndex else { return text.count..<text.count }
        return text.distance(from: text.startIndex, to: range.lowerBound)..<text.distance(from: text.startIndex, to: range.upperBound)
    }

    private func apply(_ edit: NoteEdit) {
        text = edit.text
        save(edit.text)
        DispatchQueue.main.async { select(edit.selection) }
        focused = true
    }

    private func select(_ range: Range<Int>) {
        let lower = text.index(text.startIndex, offsetBy: min(range.lowerBound, text.count))
        let upper = text.index(text.startIndex, offsetBy: min(range.upperBound, text.count))
        selection = TextSelection(range: lower..<upper)
    }

    private func placeCaretAtEnd() { select(text.count..<text.count) }

    /// Writes the note as it is typed; Return after a checklist line carries the list on.
    private func textChanged(from old: String, to new: String) {
        if new.count == old.count + 1, let caret = insertedNewline(old: old, new: new),
           let edit = NoteEditing.continuation(old: old, new: new, caret: caret) {
            text = edit.text
            save(edit.text)
            DispatchQueue.main.async { select(edit.selection) }
            return
        }
        save(new)
    }

    /// Where a single typed newline landed (the caret is just after it), found by comparing the two texts.
    private func insertedNewline(old: String, new: String) -> Int? {
        let o = Array(old), n = Array(new)
        var prefix = 0
        while prefix < o.count, o[prefix] == n[prefix] { prefix += 1 }
        return n[prefix] == "\n" ? prefix + 1 : nil
    }

    private func save(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        task.notes = trimmed.isEmpty ? nil : value
    }
}
