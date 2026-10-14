//
//  RootView.swift
//  Jamaal
//

import SwiftUI

/// The app's content. In debug builds `-JamaalWidgetGallery` shows the widget gallery instead of the app.
struct RootView: View {
    var body: some View {
        #if DEBUG
        if DebugLaunch.widgetGallery { WidgetGalleryScreen() } else { AppShell() }
        #else
        AppShell()
        #endif
    }
}
