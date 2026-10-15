//
//  MacListKeys.swift
//  Jamaal
//

#if os(macOS)
import JamaalCore
import SwiftUI

/// Today's list from the keyboard on a Mac: ↓ and ↑ move the selection (the task shown in the panel), Space marks it
/// done or not done, Delete (⌫ or forward delete) asks to drop it (the usual confirmation), Escape closes the panel.
struct MacListKeys: ViewModifier {
    var focused: SwiftUI.FocusState<Bool>.Binding
    let navigable: [TaskItem]
    let select: (TaskItem) -> Void
    let selected: TaskItem?
    let toggle: (TaskItem) -> Void
    let drop: (TaskItem) -> Void

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused(focused)
            .focusEffectDisabled()
            .onKeyPress(.downArrow) { move(.next) }
            .onKeyPress(.upArrow) { move(.previous) }
            .onKeyPress(.space) {
                guard let selected else { return .ignored }
                toggle(selected)
                return .handled
            }
            // The Delete key (⌫) reaches a focused view as AppKit's delete command, not as a key press; forward delete is a key press.
            .onDeleteCommand { dropSelected() }
            .onKeyPress(.deleteForward) {
                guard let selected, !selected.isCompleted else { return .ignored }
                dropSelected()
                return .handled
            }
    }

    private func dropSelected() {
        guard let selected, !selected.isCompleted else { return }          // a done task has nothing to drop
        drop(selected)
    }

    private func move(_ step: TaskListNavigation.Step) -> KeyPress.Result {
        guard let id = TaskListNavigation.move(step, from: selected?.id, in: navigable.map(\.id)),
              let task = navigable.first(where: { $0.id == id }) else { return .ignored }
        select(task)
        return .handled
    }
}
#endif
