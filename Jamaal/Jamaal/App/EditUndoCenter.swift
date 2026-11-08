//
//  EditUndoCenter.swift
//  Jamaal
//

import Foundation
import Observation
import SwiftData
import JamaalCore

/// The undo after editing a task in place: one toast per visit to a task, naming what changed, for five seconds. Undo puts every
/// field back as it was when the visit began. Completing, deferring and dropping are not edits and never come here.
@MainActor
@Observable
final class EditUndoCenter {
    struct Toast {
        var text: String
        var task: TaskItem
        var snapshot: TaskSnapshot
        var at: Date
    }

    static let seconds: TimeInterval = 5

    private(set) var toast: Toast?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var expiry: Task<Void, Never>?

    init(now: @escaping () -> Date = { .now }) { self.now = now }

    /// Called when a visit to `task` ends. Shows nothing if nothing changed.
    func visitEnded(task: TaskItem, snapshot: TaskSnapshot) {
        guard let text = TaskEditCopy.undoText(title: task.title, changes: TaskEditing.changes(from: snapshot, to: task)) else { return }
        let at = now()
        toast = Toast(text: text, task: task, snapshot: snapshot, at: at)
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.seconds))
            guard !Task.isCancelled else { return }
            self?.expireIfNeeded()
        }
    }

    func undo(in context: ModelContext) {
        guard let current = toast else { return }
        toast = nil
        expiry?.cancel()
        let categories = (try? context.fetch(FetchDescriptor<TaskCategory>())) ?? []
        TaskEditing.restore(current.snapshot, to: current.task, categories: categories)
        try? context.save()
    }

    func dismiss() {
        toast = nil
        expiry?.cancel()
    }

    func expireIfNeeded() {
        guard let toast, now().timeIntervalSince(toast.at) >= Self.seconds - 0.01 else { return }
        self.toast = nil
    }
}
