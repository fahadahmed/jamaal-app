import Foundation

/// When a widget needs a new entry (docs/architecture/widgets-and-watch.md, "The timeline"): at the moments that change
/// what it says, never per minute. The system keeps a budget of refreshes, so the plan is short and ends by asking
/// to be reloaded.
public enum WidgetTimeline {

    public struct Plan: Equatable, Sendable {
        /// Now, then each later moment the widget changes, oldest first.
        public var entryDates: [Date]
        /// When to ask the system for a fresh timeline: the last entry.
        public var reloadAfter: Date
    }

    /// No more than a dozen entries in one plan.
    public static let maxEntries = 12

    public static func plan(for snapshot: WidgetSnapshot, now: Date) -> Plan {
        var moments: [Date] = []
        for anchor in snapshot.anchors {
            moments.append(anchor.start)                                                    // opens
            moments.append(max(anchor.start, AnchorAttendance.closingSoonStart(windowStart: anchor.start, windowEnd: anchor.end)))
            moments.append(anchor.end)                                                      // closes
        }
        moments.append(snapshot.planningAt)                                                 // "Plan tomorrow" appears
        moments.append(snapshot.dayEndsAt)                                                  // a new day

        let later = Set(moments.filter { $0 > now }).sorted()
        let dates = Array(([now] + later).prefix(maxEntries))
        return Plan(entryDates: dates, reloadAfter: dates.last ?? now)
    }
}
