//
//  RootView.swift
//  Jamaal
//

import Observation
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
/// The width class a debug launch forces (`-JamaalWidthClass`), shared by the root view and the control that switches it.
@MainActor @Observable
final class DebugWidthClass {
    static let shared = DebugWidthClass()
    var forced = DebugLaunch.forcedWidthClass
}

#if canImport(UIKit)
/// The control that switches the forced width class lives in a window of its own, above sheets and full-screen covers, so a test can
/// fold and unfold the app while Night Planning or a sheet is open. It passes every touch through except its own tiny button.
@MainActor
enum DebugFoldWindow {
    private static var window: UIWindow?

    static func installIfNeeded() {
        guard window == nil, DebugLaunch.forcedWidthClass != nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let host = UIHostingController(rootView: ToggleButton())
        host.view.backgroundColor = .clear
        let w = PassthroughWindow(windowScene: scene)
        w.windowLevel = .alert + 100
        w.rootViewController = host
        w.backgroundColor = .clear
        w.isHidden = false
        window = w
    }

    /// Passes every touch through except those at the middle of the left edge, where the button is (a hosting view is itself the hit view
    /// for a SwiftUI control, so the test cannot be "is this the root view"). It is not at the top: the status bar zone intercepts touches
    /// there (a tap scrolls to the top), which made the control unhittable.
    private final class PassthroughWindow: UIWindow {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            point.x < 40 && abs(point.y - bounds.midY) < 48 ? super.hitTest(point, with: event) : nil
        }
    }

    private struct ToggleButton: View {
        private let model = DebugWidthClass.shared
        var body: some View {
            Button { model.forced = DebugLaunch.toggled(model.forced) } label: { Color.clear.frame(width: 28, height: 56).contentShape(Rectangle()) }
                .accessibilityLabel("Switch the width class")
                .accessibilityValue(model.forced == .regular ? "regular" : "compact")
                .accessibilityIdentifier("debugToggleWidthClass")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .ignoresSafeArea()
        }
    }
}
#endif

/// Forces the horizontal size class the app reads, with a control to switch it, and can show what the classes, the window and the crease
/// are. It changes nothing unless one of its launch arguments is given.
private struct DebugSizeHost<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.horizontalSizeClass) private var systemWidth
    @Environment(\.verticalSizeClass) private var systemHeight
    @Environment(FoldMonitor.self) private var fold
    private let model = DebugWidthClass.shared

    private var width: UserInterfaceSizeClass? { model.forced ?? systemWidth }

    var body: some View {
        content
            .environment(\.horizontalSizeClass, width)
            #if canImport(UIKit)
            .onAppear { DebugFoldWindow.installIfNeeded() }
            #endif
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
