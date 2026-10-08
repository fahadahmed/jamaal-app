//
//  PlatformShims.swift
//  Jamaal
//

import SwiftUI

/// The few SwiftUI calls that exist on iOS and not on macOS, in one place. Each does the iOS thing on iOS and the nearest Mac
/// thing on macOS, so the screens read the same on both.
/// The Mac window's size: it opens at the default and can't be dragged smaller than the minimum, which is big enough for
/// every sheet (a Night Planning canvas included) to sit inside it.
enum MacWindow {
    static let minWidth: CGFloat = 980
    static let minHeight: CGFloat = 720
    static let defaultWidth: CGFloat = 1180
    static let defaultHeight: CGFloat = 780
}

/// How big a Mac sheet is. A sheet sizes to its content's ideal size, and these screens are scroll views with none, so they
/// would open as a small box: a flow built for a whole screen says how much of a window it needs.
enum MacSheetSize {
    /// A single column: onboarding, the paywall, the focus screen, the note editor.
    case page
    /// A whole canvas: Night Planning's rail and its step beside it.
    case canvas

    /// A sheet opens at its minimum width and its ideal height (macOS takes the minimum for the width), so the minimum is the
    /// size wanted; the window is never narrower or shorter than the canvas (`MacWindow`).
    var width: ClosedRange<CGFloat> { self == .canvas ? 960...1100 : 560...680 }
    var height: ClosedRange<CGFloat> { self == .canvas ? 600...700 : 560...700 }
}

extension View {
    /// iOS: a full-screen cover. macOS has none, so it is a sheet of the given size.
    @ViewBuilder
    func fullScreenCoverOrSheet<Content: View>(
        isPresented: Binding<Bool>, macSize: MacSheetSize = .page, onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss) { content().macSheetFrame(macSize) }
        #else
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    @ViewBuilder
    func fullScreenCoverOrSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>, macSize: MacSheetSize = .page, onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, onDismiss: onDismiss) { content($0).macSheetFrame(macSize) }
        #else
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #endif
    }

    #if os(macOS)
    /// Smallest and ideal size for a Mac sheet; it opens at the ideal size and can be dragged no smaller than the minimum.
    fileprivate func macSheetFrame(_ size: MacSheetSize) -> some View {
        frame(idealWidth: size.width.upperBound, idealHeight: size.height.upperBound)
            .frame(minWidth: size.width.lowerBound, minHeight: size.height.lowerBound)
    }
    #endif

    /// The screens draw their own headers, so the system navigation bar is hidden (macOS has none to hide in a stack).
    @ViewBuilder
    func hidesNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// The bar behind a navigation bar's items is transparent, so the app's ground shows through.
    @ViewBuilder
    func clearNavigationBarBackground() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// A small inline title in a form's navigation bar (macOS titles its sheets differently).
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    /// The leading and trailing ends of the top bar on iOS; the Mac toolbar's navigation and primary-action slots.
    static var jamaalLeading: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    static var jamaalTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}
