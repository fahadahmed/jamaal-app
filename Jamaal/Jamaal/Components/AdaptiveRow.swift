//
//  AdaptiveRow.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A title and its value on one line, which stack at accessibility text sizes so each gets a full line instead
/// of the title breaking mid-word ("Mornin / g") beside a squeezed value.
struct AdaptiveRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var spacing: CGFloat = ThreadsSpace.tight
    var alignment: VerticalAlignment = .center
    let leading: Leading
    let trailing: Trailing

    init(spacing: CGFloat = ThreadsSpace.tight, alignment: VerticalAlignment = .center,
         @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.spacing = spacing; self.alignment = alignment
        self.leading = leading(); self.trailing = trailing()
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) {
                leading
                trailing
            }
        } else {
            HStack(alignment: alignment, spacing: spacing) {
                leading
                Spacer(minLength: spacing)
                trailing
            }
        }
    }
}

/// A row of equal buttons ("Look at it" · "Not now") that stack at accessibility text sizes.
struct AdaptiveButtons<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var spacing: CGFloat = ThreadsSpace.tight
    @ViewBuilder let content: Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
        layout { content }
    }
}
