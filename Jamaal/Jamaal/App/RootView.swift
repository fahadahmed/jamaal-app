//
//  RootView.swift
//  Jamaal
//

import SwiftUI

/// The app's content. It reads where a foldable iPhone's crease is (`FoldMonitor`) for the layouts that follow it. In debug builds
/// `-JamaalWidgetGallery` shows the widget gallery instead of the app, and `-JamaalWidthClass` and `-JamaalSizeHUD` stand in for the two
/// displays of an iPhone Duo (#329).
struct RootView: View {
    @State private var fold = FoldMonitor()

    var body: some View {
        content
            .environment(fold)
            #if canImport(UIKit)
            .background { FoldReader(monitor: fold).ignoresSafeArea().allowsHitTesting(false) }
            #endif
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        DebugSizeHost {
            if DebugLaunch.widgetGallery { WidgetGalleryScreen() } else { AppShell() }
        }
        #else
        AppShell()
        #endif
    }
}

#if DEBUG
/// Forces the horizontal size class the app reads, with a control to switch it, and can show what the classes, the window and the crease
/// are. It changes nothing unless one of its launch arguments is given.
private struct DebugSizeHost<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.horizontalSizeClass) private var systemWidth
    @Environment(\.verticalSizeClass) private var systemHeight
    @Environment(FoldMonitor.self) private var fold
    @State private var forced = DebugLaunch.forcedWidthClass

    private var width: UserInterfaceSizeClass? { forced ?? systemWidth }

    var body: some View {
        content
            .environment(\.horizontalSizeClass, width)
            .overlay(alignment: .topLeading) {
                if forced != nil {
                    Button { forced = DebugLaunch.toggled(forced) } label: { Color.clear.frame(width: 44, height: 16) }
                        .accessibilityLabel("Switch the width class")
                        .accessibilityValue(forced == .regular ? "regular" : "compact")
                        .accessibilityIdentifier("debugToggleWidthClass")
                }
            }
            .overlay(alignment: .bottomLeading) {
                if DebugLaunch.sizeHUD {
                    GeometryReader { proxy in
                        let i = proxy.safeAreaInsets
                        Text("W \(name(width)) H \(name(systemHeight)) \(Int(proxy.size.width))x\(Int(proxy.size.height)) insets L\(Int(i.leading)) T\(Int(i.top)) R\(Int(i.trailing)) B\(Int(i.bottom))\n\(fold.summary)")
                            .font(.system(size: 9, design: .monospaced)).padding(2).background(.black.opacity(0.6)).foregroundStyle(.white)
                            .accessibilityIdentifier("sizeHUD")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private func name(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "?"
        }
    }
}
#endif
