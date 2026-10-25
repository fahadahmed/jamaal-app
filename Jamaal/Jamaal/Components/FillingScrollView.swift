//
//  FillingScrollView.swift
//  Jamaal
//

import SwiftUI
import ThreadsTokens

/// A scroll view for a screen that has always been laid out to fill the height (a `Spacer` pushes its last button to the bottom).
/// When the content fits, it looks and behaves exactly as before; when it doesn't (a phone in landscape is about 390 points tall),
/// it scrolls, so nothing is cut off and the buttons stay reachable (#315).
struct FillingScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
}

extension EnvironmentValues {
    /// A phone held sideways: the height is short (about 390 points), so a layout drops its large titles and tall paddings.
    var isShortHeight: Bool { verticalSizeClass == .compact }
}

/// A page title: the large display size, or the compact one when the phone is held sideways and the height is short (#315).
private struct PageTitle: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        content.threadsType(.display(verticalSizeClass == .compact ? .compact : .large))
    }
}

extension View {
    func pageTitle() -> some View { modifier(PageTitle()) }
}
