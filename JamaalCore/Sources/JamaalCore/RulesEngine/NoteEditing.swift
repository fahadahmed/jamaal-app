import Foundation

/// The note editor's result: the new text and where the selection (or caret, when empty) goes, in characters.
public struct NoteEdit: Equatable, Sendable {
    public var text: String
    public var selection: Range<Int>

    public init(text: String, selection: Range<Int>) {
        self.text = text
        self.selection = selection
    }
}

/// The note editor's formatting rules (TK-04), as pure functions on text and a character selection: toggle a checklist on
/// the selected lines, wrap or unwrap bold, italic and inline code, make a link, and keep a checklist going when Return is
/// pressed. The note stays plain markdown (docs/schema/task.md), so what is written here is what the detail and the focus
/// screen render and tick.
public enum NoteEditing {

    public static let unchecked = "- [ ] "
    public static let bullet = "- "

    // MARK: Checklist

    /// Turns the selected lines into checklist items, or, if they all already are, back into plain lines. A bullet becomes a
    /// checklist item; a ticked item stays ticked until it is turned back.
    public static func toggleChecklist(_ text: String, selection: Range<Int>) -> NoteEdit {
        let characters = Array(text)
        let range = clamp(selection, characters.count)
        let start = lineStart(characters, at: range.lowerBound)
        let end = lineEnd(characters, at: range.isEmpty ? range.lowerBound : max(range.lowerBound, range.upperBound - 1))
        let lines = String(characters[start..<end]).components(separatedBy: "\n")
        let allChecklist = lines.allSatisfy { checklistPrefixLength($0) != nil }
        let changed = lines.map { line -> String in
            if allChecklist { return String(line.dropFirst(checklistPrefixLength(line) ?? 0)) }
            if checklistPrefixLength(line) != nil { return line }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return unchecked + line.dropFirst(2) }
            return unchecked + line
        }
        let replacement = changed.joined(separator: "\n")
        let result = String(characters[..<start]) + replacement + String(characters[end...])
        let caret = start + replacement.count
        return NoteEdit(text: result, selection: range.isEmpty ? caret..<caret : start..<caret)
    }

    // MARK: Wrapping

    /// Wraps the selection in `marker` (`**`, `*` or `` ` ``), or removes the marker if the selection is already wrapped in
    /// exactly it. With nothing selected it places the markers with the caret between, or removes an empty pair.
    public static func wrap(_ text: String, selection: Range<Int>, marker: String) -> NoteEdit {
        let characters = Array(text)
        let range = clamp(selection, characters.count)
        let m = Array(marker)
        let before = Array(characters[..<range.lowerBound]), after = Array(characters[range.upperBound...])
        if before.count >= m.count, after.count >= m.count, Array(before.suffix(m.count)) == m, Array(after.prefix(m.count)) == m,
           isExactlyThisMarker(before, after, m) {
            let result = String(before.dropLast(m.count)) + String(characters[range]) + String(after.dropFirst(m.count))
            let start = range.lowerBound - m.count
            return NoteEdit(text: result, selection: start..<(start + range.count))
        }
        let inner = String(characters[range])
        let result = String(before) + marker + inner + marker + String(after)
        let start = range.lowerBound + m.count
        return NoteEdit(text: result, selection: start..<(start + range.count))
    }

    /// A single `*` next to another `*` is part of bold, not an italic marker.
    private static func isExactlyThisMarker(_ before: [Character], _ after: [Character], _ marker: [Character]) -> Bool {
        guard marker == ["*"] else { return true }
        let beforeStars = before.reversed().prefix { $0 == "*" }.count
        let afterStars = after.prefix { $0 == "*" }.count
        return beforeStars == 1 && afterStars == 1
    }

    public static func bold(_ text: String, selection: Range<Int>) -> NoteEdit { wrap(text, selection: selection, marker: "**") }
    public static func italic(_ text: String, selection: Range<Int>) -> NoteEdit { wrap(text, selection: selection, marker: "*") }
    public static func code(_ text: String, selection: Range<Int>) -> NoteEdit { wrap(text, selection: selection, marker: "`") }

    // MARK: Link

    public static let placeholderAddress = "https://"

    /// `[the selection](https://)` with the address selected so it can be typed over; with nothing selected, `[link](https://)`.
    public static func link(_ text: String, selection: Range<Int>) -> NoteEdit {
        let characters = Array(text)
        let range = clamp(selection, characters.count)
        let label = range.isEmpty ? "link" : String(characters[range])
        let result = String(characters[..<range.lowerBound]) + "[" + label + "](" + placeholderAddress + ")" + String(characters[range.upperBound...])
        let addressStart = range.lowerBound + 1 + label.count + 2
        return NoteEdit(text: result, selection: addressStart..<(addressStart + placeholderAddress.count))
    }

    // MARK: Return

    /// When a single newline was just typed at the caret after a checklist (or bullet) line, the next line starts the same
    /// way; if that item was empty, the list ends instead (the empty item is removed). `nil` for any other edit.
    public static func continuation(old: String, new: String, caret: Int) -> NoteEdit? {
        let o = Array(old), n = Array(new)
        guard n.count == o.count + 1, caret >= 1, caret <= n.count, n[caret - 1] == "\n",
              Array(n[..<(caret - 1)]) + Array(n[caret...]) == o else { return nil }
        let start = lineStart(n, at: caret - 1)
        let line = String(n[start..<(caret - 1)])
        let prefix: String
        if let length = checklistPrefixLength(line) { prefix = unchecked; return finish(n, start, caret, line, length, prefix) }
        if line.hasPrefix("- ") { prefix = bullet; return finish(n, start, caret, line, 2, prefix) }
        return nil
    }

    private static func finish(_ n: [Character], _ start: Int, _ caret: Int, _ line: String, _ prefixLength: Int, _ prefix: String) -> NoteEdit {
        if line.dropFirst(prefixLength).trimmingCharacters(in: .whitespaces).isEmpty {
            // An empty item ends the list: drop its marker and the newline just typed.
            let result = String(n[..<start]) + String(n[caret...])
            return NoteEdit(text: result, selection: start..<start)
        }
        let result = String(n[..<caret]) + prefix + String(n[caret...])
        let place = caret + prefix.count
        return NoteEdit(text: result, selection: place..<place)
    }

    // MARK: Helpers

    /// Length of a leading `- [ ] `, `- [x] ` (any of `-*+`), or `nil` if the line isn't a checklist item.
    private static func checklistPrefixLength(_ line: String) -> Int? {
        let c = Array(line)
        guard c.count >= 6, "-*+".contains(c[0]), c[1] == " ", c[2] == "[", " xX".contains(c[3]), c[4] == "]", c[5] == " " else {
            if c.count == 5, "-*+".contains(c[0]), c[1] == " ", c[2] == "[", " xX".contains(c[3]), c[4] == "]" { return 5 }
            return nil
        }
        return 6
    }

    private static func clamp(_ range: Range<Int>, _ count: Int) -> Range<Int> {
        let lower = max(0, min(range.lowerBound, count)), upper = max(lower, min(range.upperBound, count))
        return lower..<upper
    }

    private static func lineStart(_ c: [Character], at index: Int) -> Int {
        var i = min(index, c.count)
        while i > 0, c[i - 1] != "\n" { i -= 1 }
        return i
    }

    private static func lineEnd(_ c: [Character], at index: Int) -> Int {
        var i = min(index, c.count)
        while i < c.count, c[i] != "\n" { i += 1 }
        return i
    }
}
