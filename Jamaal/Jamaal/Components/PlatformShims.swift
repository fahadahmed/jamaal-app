//
//  PlatformShims.swift
//  Jamaal
//

import SwiftUI

/// The few SwiftUI calls that exist on iOS and not on macOS, in one place. Each does the iOS thing on iOS and the nearest Mac
/// thing on macOS, so the screens read the same on both.
extension View {
    /// iOS: a full-screen cover. macOS has none, so it is a sheet.
    @ViewBuilder
    func fullScreenCoverOrSheet<Content: View>(
        isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    @ViewBuilder
    func fullScreenCoverOrSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, onDismiss: onDismiss, content: content)
        #else
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #endif
    }

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
