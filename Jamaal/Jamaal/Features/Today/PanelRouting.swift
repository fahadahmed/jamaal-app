//
//  PanelRouting.swift
//  Jamaal
//

import SwiftUI
import JamaalCore

private struct OpenTaskInPanelKey: EnvironmentKey {
    static let defaultValue: ((TaskItem) -> Void)? = nil
}

extension EnvironmentValues {
    /// Set by Today when it shows a detail panel beside the list (iPad, Mac, a foldable's inner display): a screen pushed into the list
    /// column (Coming up) opens a task there instead of in a sheet, so "the list is a list, the detail is a view of one thing". `nil` on a phone.
    var openTaskInPanel: ((TaskItem) -> Void)? {
        get { self[OpenTaskInPanelKey.self] }
        set { self[OpenTaskInPanelKey.self] = newValue }
    }
}

extension CommandCenter {
    /// Mac: Return with a task selected starts editing its title; the open detail takes focus when it sees this change.
    func requestEditTitle() { editTitleRequests += 1 }
}
