import Foundation

/// One line of a task's note.
public struct TaskNoteItem: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case checkbox(isDone: Bool)
        case text
    }
    /// The zero-based line in the note, used to toggle it.
    public var line: Int
    public var kind: Kind
    /// The line without its bullet and box: still markdown (bold, italic, links, inline code).
    public var text: String
}

public struct TaskNoteProgress: Equatable, Sendable {
    public var done: Int
    public var total: Int
}

/// A task's note is optional lightweight markdown scoped to the one task (docs/schema/task.md). Its checklist lines
/// (`- [ ] item`, `* [x] item`) are tappable on the detail sheet and the focus screen; everything else is plain text.
public enum TaskNotes {

    /// The non-blank lines, checklist lines as checkboxes.
    public static func items(_ note: String?) -> [TaskNoteItem] {
        guard let note, !note.isEmpty else { return [] }
        var items: [TaskNoteItem] = []
        for (index, raw) in note.components(separatedBy: "\n").enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let (isDone, text) = checkbox(in: line) {
                items.append(TaskNoteItem(line: index, kind: .checkbox(isDone: isDone), text: text))
            } else {
                items.append(TaskNoteItem(line: index, kind: .text, text: line))
            }
        }
        return items
    }

    /// The note with the box on `line` flipped, changing nothing else, or `nil` if that line isn't a checkbox.
    public static func toggled(_ note: String?, line: Int) -> String? {
        guard let note else { return nil }
        var lines = note.components(separatedBy: "\n")
        guard lines.indices.contains(line), let (isDone, _) = checkbox(in: lines[line].trimmingCharacters(in: .whitespaces)),
              let open = lines[line].firstIndex(of: "["), let close = lines[line].firstIndex(of: "]") else { return nil }
        lines[line].replaceSubrange(lines[line].index(after: open)..<close, with: isDone ? " " : "x")
        return lines.joined(separator: "\n")
    }

    public static func progress(_ note: String?) -> TaskNoteProgress {
        let boxes = items(note).compactMap { item -> Bool? in
            if case .checkbox(let done) = item.kind { return done }
            return nil
        }
        return TaskNoteProgress(done: boxes.filter { $0 }.count, total: boxes.count)
    }

    /// `- [ ] text`, `* [x] text`, `+ [X] text`: a bullet, a space, a box, a space and some text.
    private static func checkbox(in line: String) -> (isDone: Bool, text: String)? {
        let characters = Array(line)
        // The shortest checklist line is "- [ ] x"; a trimmed line of that length has text after the box.
        guard characters.count >= 7, "-*+".contains(characters[0]), characters[1] == " ", characters[2] == "[",
              " xX".contains(characters[3]), characters[4] == "]", characters[5] == " " else { return nil }
        return (characters[3] != " ", String(characters[6...]).trimmingCharacters(in: .whitespaces))
    }
}
