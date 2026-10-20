import Foundation

/// What the Next Anchor Lock Screen widgets say (frame WG-02), in each of the three accessory sizes. Built from a `WidgetSnapshot`
/// like every other widget. `time` formats a clock time the way the device does, so the words are testable.
public struct LockScreenAnchorDisplay: Equatable, Sendable {

    /// The line beside the date: "Dhuhr · until 15:32".
    public var inline: String

    public struct Circular: Equatable, Sendable {
        public enum Ring: Equatable, Sendable {
            /// A window that is open or closing: the ring fills as it passes.
            case progress(Double)
            /// A window that hasn't opened: a dashed outline.
            case outline
            /// A window that closed unmarked: neutral and full.
            case neutral
            /// Nothing to show.
            case none
        }
        /// The small word above the time ("Dhuhr", "opens").
        public var label: String
        /// The big figure: when the window ends (or opens), or "None".
        public var value: String
        public var ring: Ring
        public init(label: String, value: String, ring: Ring) { self.label = label; self.value = value; self.ring = ring }
    }
    public var circular: Circular

    public struct Rectangular: Equatable, Sendable {
        public var title: String
        public var subtitle: String?
        public var bar: NextAnchorCopy.Bar?
        public init(title: String, subtitle: String?, bar: NextAnchorCopy.Bar?) { self.title = title; self.subtitle = subtitle; self.bar = bar }
    }
    public var rectangular: Rectangular
}

public extension WidgetSnapshot {

    /// - Parameter shortTime: how the circular widget writes a clock time, which has no room for "pm"; defaults to `time`.
    func lockScreenAnchorDisplay(time: @escaping (Date) -> String, shortTime: ((Date) -> String)? = nil) -> LockScreenAnchorDisplay {
        let short = shortTime ?? time
        let display = nextAnchorDisplay
        let bar = NextAnchorCopy.bar(display).map { NextAnchorCopy.Bar(fill: min(1, max(0, $0.fill)), style: $0.style) }

        switch display {
        case .open(let w), .closingSoon(let w):
            let closing: Bool = { if case .closingSoon = display { return true } else { return false } }()
            let minutesLeft = max(1, Int((w.end.timeIntervalSince(generatedAt) / 60).rounded(.up)))
            let following = anchors.dropFirst().first { $0.phase == .upcoming }
            let subtitle = closing ? "closes in \(minutesLeft) min" : following.map { "\($0.name) opens \(time($0.start))" }
            let until = "\(w.name) · until \(time(w.end))"
            return .init(
                inline: until,
                circular: .init(label: w.name, value: short(w.end), ring: .progress(bar?.fill ?? 0)),
                rectangular: .init(title: until, subtitle: subtitle, bar: bar))

        case .upcoming(let w):
            return .init(
                inline: "\(w.name) · from \(time(w.start))",
                circular: .init(label: "opens", value: short(w.start), ring: .outline),
                rectangular: .init(title: w.name, subtitle: "opens \(time(w.start))", bar: bar))

        case .needsAttention(let w):
            return .init(
                inline: "\(w.name) · not marked yet",
                circular: .init(label: w.name, value: short(w.end), ring: .neutral),
                rectangular: .init(title: w.name, subtitle: "Not marked yet", bar: bar))

        case .noneLeft:
            guard let next = tomorrowAnchor else {
                return .init(
                    inline: "Nothing more today",
                    circular: .init(label: "Anchors", value: "None", ring: .none),
                    rectangular: .init(title: "Nothing more today", subtitle: nil, bar: nil))
            }
            return .init(
                inline: "Nothing more today",
                circular: .init(label: next.name, value: short(next.start), ring: .none),
                rectangular: .init(title: "Nothing more today", subtitle: "\(next.name) tomorrow, \(time(next.start))", bar: nil))
        }
    }
}
