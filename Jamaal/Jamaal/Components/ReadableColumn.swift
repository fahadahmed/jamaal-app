//
//  ReadableColumn.swift
//  Jamaal
//

import SwiftUI

extension View {
    /// Caps a screen's content at a readable width and centres it in a wider pane (iPad, Mac), so a detail doesn't run
    /// edge to edge, left-aligned within the column and always filling the pane however little it holds. On a phone it changes nothing.
    func readableColumn(maxWidth: CGFloat = 720) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading).frame(maxWidth: .infinity)
    }
}
