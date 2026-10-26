//
//  FoldMonitor.swift
//  Jamaal
//

import JamaalCore
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
import os
#endif

/// Where the crease of a foldable iPhone is (the iPhone Duo, iOS 27.1). The system reports it as a *division* reserved region of the
/// window; `FoldLayout` (JamaalCore) decides whether a region is a crease the side-by-side layout should follow. Today's list then runs
/// up to it and the details pane starts at it, instead of splitting at a width of its own (#329). `creaseX` is nil on every other
/// device, on an older system, and whenever the device is open flat.
@MainActor @Observable
final class FoldMonitor {
    /// The x position of a vertical crease, in the window's coordinates.
    private(set) var creaseX: CGFloat?
    /// What the system reported, for the debug overlay.
    private(set) var summary = ""

    func update(creaseX: CGFloat?, summary: String) {
        if self.creaseX != creaseX { self.creaseX = creaseX }
        if self.summary != summary { self.summary = summary }
    }
}

#if canImport(UIKit)
/// A view that fills the window and reads its reserved regions into a `FoldMonitor`. There is no change notification for them, so they
/// are read on every layout and twice a second while the app is on screen (a pose changes at the speed of a hand). Nothing is kept or sent.
struct FoldReader: UIViewRepresentable {
    let monitor: FoldMonitor

    func makeUIView(context: Context) -> Probe { Probe(monitor: monitor) }
    func updateUIView(_ uiView: Probe, context: Context) {}

    final class Probe: UIView {
        private let monitor: FoldMonitor
        private var last = ""
        private var timer: Timer?

        init(monitor: FoldMonitor) {
            self.monitor = monitor
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            NotificationCenter.default.addObserver(self, selector: #selector(start), name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(stop), name: UIApplication.willResignActiveNotification, object: nil)
            start()
        }
        required init?(coder: NSCoder) { fatalError() }
        deinit { timer?.invalidate() }

        @objc private func start() {
            guard timer == nil, #available(iOS 27.1, *) else { return }
            let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.read() }
            t.tolerance = 0.25
            timer = t
            read()
        }

        @objc private func stop() { timer?.invalidate(); timer = nil }

        override func layoutSubviews() { super.layoutSubviews(); read() }

        private func read() {
            guard #available(iOS 27.1, *) else { return }
            let found = reservedRegions(kind: .division, options: [.includeInactive])
            let regions = found.map {
                FoldLayout.Region(minX: $0.frame.minX, maxX: $0.frame.maxX, minY: $0.frame.minY, maxY: $0.frame.maxY, isActive: $0.isActive)
            }
            let crease = FoldLayout.crease(in: regions, viewSize: bounds.size)
            let describe = found.map {
                "division \($0.isActive ? "active" : "inactive") x\(Int($0.frame.minX))-\(Int($0.frame.maxX)) y\(Int($0.frame.minY))-\(Int($0.frame.maxY))"
            }
            let summary = "view \(Int(bounds.width))x\(Int(bounds.height)) " + (describe.isEmpty ? "no regions" : describe.joined(separator: " | "))
                + (crease.map { " -> crease \(Int($0))" } ?? " -> no crease")
            guard summary != last else { return }
            last = summary
            Logger(subsystem: "dev.fhdamd.Jamaal", category: "app").notice("fold \(summary, privacy: .public)")
            monitor.update(creaseX: crease, summary: summary)
        }
    }
}
#endif
