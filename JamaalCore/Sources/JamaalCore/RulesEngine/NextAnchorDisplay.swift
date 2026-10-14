import Foundation

/// Which of the small Next Anchor widget's five states a snapshot is in (frame WG-01).
public enum NextAnchorDisplay: Equatable, Sendable {
    case open(WidgetSnapshot.AnchorWindow)
    case closingSoon(WidgetSnapshot.AnchorWindow)
    case upcoming(WidgetSnapshot.AnchorWindow)
    /// The window closed and nothing was logged. Only shown when nothing is open or coming.
    case needsAttention(WidgetSnapshot.AnchorWindow)
    case noneLeft
}

public extension WidgetSnapshot {
    var nextAnchorDisplay: NextAnchorDisplay {
        guard let lead = anchors.first else { return .noneLeft }       // open first, then upcoming, then unmarked
        switch lead.phase {
        case .open: return .open(lead)
        case .closingSoon: return .closingSoon(lead)
        case .upcoming: return .upcoming(lead)
        case .needsAttention: return .needsAttention(lead)
        }
    }
}

/// The words and the bar of the Next Anchor widget. Plain facts: a clock time, never a countdown, and no red.
public enum NextAnchorCopy {

    public struct Bar: Equatable, Sendable {
        public enum Style: Equatable, Sendable {
            /// The accent colour, for an open or closing window.
            case accent
            /// An outline with no fill, for a window that hasn't opened.
            case outline
            /// Neutral and full, for a window that is over and unrecorded.
            case neutral
        }
        public var fill: Double
        public var style: Style
        public init(fill: Double, style: Style) { self.fill = fill; self.style = style }
    }

    /// The small line above the name ("Salah · open"); the widget sets it in its label type, which uppercases it.
    public static func eyebrow(_ display: NextAnchorDisplay) -> String {
        switch display {
        case .open(let window): [window.ruleTitle, "open"].compactMap { $0 }.joined(separator: " · ").capitalizedFirst
        case .closingSoon(let window): [window.ruleTitle, "closing"].compactMap { $0 }.joined(separator: " · ").capitalizedFirst
        case .upcoming: "Next"
        case .needsAttention: "Not marked yet"
        case .noneLeft: "Anchors"
        }
    }

    public static func title(_ display: NextAnchorDisplay) -> String {
        switch display {
        case .open(let window), .closingSoon(let window), .upcoming(let window), .needsAttention(let window): window.name
        case .noneLeft: "Nothing more today."
        }
    }

    /// "until 15:32", "opens 15:00", "Closed at 21:00"; `time` formats a clock time the way the device does.
    public static func detail(_ display: NextAnchorDisplay, time: (Date) -> String) -> String? {
        switch display {
        case .open(let window), .closingSoon(let window): "until \(time(window.end))"
        case .upcoming(let window): "opens \(time(window.start))"
        case .needsAttention(let window): "Closed at \(time(window.end))"
        case .noneLeft: nil
        }
    }

    public static func bar(_ display: NextAnchorDisplay) -> Bar? {
        switch display {
        case .open(let window), .closingSoon(let window): Bar(fill: min(1, max(0, window.progress)), style: .accent)
        case .upcoming: Bar(fill: 0, style: .outline)
        case .needsAttention: Bar(fill: 1, style: .neutral)
        case .noneLeft: nil
        }
    }
}

private extension String {
    /// "salah · open" would not do: keep a rule's own capitals and only raise the first letter of a bare state.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
