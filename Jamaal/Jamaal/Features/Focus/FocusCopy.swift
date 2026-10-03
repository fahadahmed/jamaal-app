//
//  FocusCopy.swift
//  Jamaal
//

import Foundation
import JamaalCore

/// The chip's, the focus screen's and the finish sheet's words. A timer is a fact, never a verdict: nothing here
/// changes tone when a session runs past its estimate.
enum FocusCopy {

    /// "24:10", or "1:14:12" from an hour on.
    static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func ofEstimate(_ minutes: Int?) -> String? { minutes.map { "of \($0) min" } }

    /// Whole minutes, rounded, but never "0" for time that was actually spent.
    private static func minutes(_ seconds: Int) -> Int {
        seconds <= 0 ? 0 : max(1, Int((Double(seconds) / 60).rounded()))
    }

    static func actualVersusEstimate(seconds: Int, estimate: Int?) -> String {
        let actual = "\(minutes(seconds)) min"
        return estimate.map { "\(actual) · estimated \($0)" } ?? actual
    }

    static func stopForNowNote(seconds: Int) -> String {
        "Stop for now keeps the \(minutes(seconds)) min and leaves the task on today."
    }

    static func edgeLine(_ edge: ApproachingEdge) -> String {
        switch edge.kind {
        case .closing: "\(edge.title) closes in \(edge.minutes) min"
        case .opening: "\(edge.title) in \(edge.minutes) min"
        }
    }

    /// A task row's timing: "Timing · 24 min" while live, the total once it has been worked on, otherwise nothing.
    static func timingMeta(trackedSeconds: Int, isLive: Bool) -> String? {
        let m = Int((Double(max(0, trackedSeconds)) / 60).rounded())
        if isLive { return m == 0 ? "Timing" : "Timing · \(m) min" }
        return m == 0 ? nil : "\(m) min"
    }

    static func settleEyebrow(minutes: Int) -> String { "Timing now · \(minutes) min" }
    static let settleLine = "Settle this one first. Its time is kept whichever you pick."
    static func thenBegin(_ title: String) -> String { "Then Begin \"\(title)\"" }

    static func doneToast(_ title: String) -> String { "Done · \(title)" }
    static func pauseTitle(isPaused: Bool) -> String { isPaused ? "Resume" : "Pause" }
}
