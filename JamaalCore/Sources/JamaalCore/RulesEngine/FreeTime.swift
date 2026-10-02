import Foundation

/// Module 7, free time: the physical day, kept apart from the energy budget
/// (docs/architecture/rules-engine.md).
///
/// The working day runs from `dayStartMinute` to `dayEndMinute`; for today it starts at the later
/// of now and the day's start. **Fixed** commitments are busy blocks that *cut* the day into free
/// blocks. **Flexible** commitments and habit minutes come off the total but don't cut it,
/// because their position within the day isn't fixed. Only busy time inside the working day
/// counts, so an Anchor after the day's end doesn't fragment it. Nothing here blocks anything:
/// it only measures.
public enum FreeTime {

    /// Gaps shorter than this are not shown (they still count as free time).
    public static let minimumVisibleGapMinutes = 20

    /// Something that takes time from the day.
    public struct Commitment: Equatable, Sendable {
        public var title: String
        /// Fixed: when it starts. Flexible: when its window opens.
        public var start: Date
        /// When its window closes (used to decide whether a flexible commitment overlaps the day).
        public var windowEnd: Date
        public var minutes: Int
        public var isFixed: Bool

        public init(title: String, start: Date, windowEnd: Date, minutes: Int, isFixed: Bool) {
            self.title = title
            self.start = start
            self.windowEnd = windowEnd
            self.minutes = minutes
            self.isFixed = isFixed
        }
    }

    /// A stretch of the working day with nothing fixed in it.
    public struct Block: Equatable, Sendable {
        public var start: Date
        public var end: Date
        public var minutes: Int
        /// The fixed commitment this gap ends at ("before the school run"), if any.
        public var before: String?
        /// The fixed commitment this gap begins after ("after the dentist"), if any.
        public var after: String?
    }

    public struct Result: Equatable, Sendable {
        /// Every free block, in order, including short ones.
        public var blocks: [Block]
        /// Blocks long enough to show (20 minutes or more).
        public var visibleBlocks: [Block] { blocks.filter { $0.minutes >= FreeTime.minimumVisibleGapMinutes } }
        /// The blocks' total minus flexible commitments and habit minutes, never below zero.
        public var freeMinutes: Int
        /// Fixed (merged), flexible and habit minutes inside the working day: what can't be deferred.
        public var committedMinutes: Int
        /// The longest free block, which is what a task has to fit in.
        public var longestBlockMinutes: Int
    }

    /// Free time for one logical day.
    ///
    /// - Parameter now: pass the current instant for *today*, so only what is left of the day
    ///   counts; pass `nil` for any other day.
    /// - Parameter habitMinutes: the minutes of habit windows still to do that day.
    public static func compute(
        day: CalendarDate,
        boundary: DayBoundary,
        dayStartMinute: Int,
        dayEndMinute: Int,
        now: Date?,
        commitments: [Commitment],
        habitMinutes: Int
    ) -> Result {
        let dayStart = boundary.instant(of: day, atMinute: dayStartMinute)
        let dayEnd = boundary.instant(of: day, atMinute: dayEndMinute)
        let start = now.map { max($0, dayStart) } ?? dayStart
        guard start < dayEnd else { return Result(blocks: [], freeMinutes: 0, committedMinutes: 0, longestBlockMinutes: 0) }

        let busy = mergedBusyIntervals(commitments.filter { $0.isFixed && $0.minutes > 0 }, from: start, to: dayEnd)

        var blocks: [Block] = []
        var cursor = start
        var previousTitle: String?
        for interval in busy {
            if interval.start > cursor {
                blocks.append(block(cursor, interval.start, before: interval.firstTitle, after: previousTitle))
            }
            cursor = interval.end
            previousTitle = interval.lastTitle
        }
        if cursor < dayEnd {
            blocks.append(block(cursor, dayEnd, before: nil, after: previousTitle))
        }
        blocks.removeAll { $0.minutes == 0 }

        let flexibleMinutes = commitments
            .filter { !$0.isFixed && $0.minutes > 0 && $0.windowEnd > start && $0.start < dayEnd }
            .reduce(0) { $0 + $1.minutes }
        let fixedMinutes = busy.reduce(0) { $0 + minutes(from: $1.start, to: $1.end) }
        let total = blocks.reduce(0) { $0 + $1.minutes }

        return Result(
            blocks: blocks,
            freeMinutes: max(0, total - flexibleMinutes - habitMinutes),
            committedMinutes: fixedMinutes + flexibleMinutes + habitMinutes,
            longestBlockMinutes: blocks.map(\.minutes).max() ?? 0
        )
    }

    // MARK: From the models

    /// The commitments an Anchor list contributes: only `pending` ones count (skipped, delegated,
    /// attended and missed ones no longer take the day's time). An Anchor is fixed unless its rule
    /// is `flexible`; one-offs have no rule and are fixed.
    ///
    /// `afterLast` ("N–M days after I last did it") Anchors are always flexible, whatever the rule's `placement`.
    public static func commitments(from anchors: [Anchor]) -> [Commitment] {
        anchors
            .filter { $0.status == .pending }
            .map {
                Commitment(
                    title: $0.title,
                    start: $0.windowStart,
                    windowEnd: $0.windowEnd,
                    minutes: max(0, $0.effortMinutes ?? 0),
                    isFixed: $0.rule?.placementKind != .flexible && $0.rule?.isAfterLast != true
                )
            }
    }

    // MARK: Signals

    /// Planned task minutes beyond the day's free time ("2h 10m past 19:00").
    public static func overflowMinutes(plannedMinutes: Int, freeMinutes: Int) -> Int {
        max(0, plannedMinutes - freeMinutes)
    }

    /// The highest level whose budget fits within the free time, never below `low`. The user
    /// always decides.
    public static func suggestedCapacity(freeMinutes: Int, mediumDayMinutes: Int) -> CapacityLevel {
        for level in [CapacityLevel.high, .medium]
        where CapacityLoad.budgetMinutes(for: level, mediumDayMinutes: mediumDayMinutes) <= freeMinutes {
            return level
        }
        return .low
    }

    /// Tasks whose estimate is longer than the longest free block. A quiet flag, never blocking;
    /// a task with no estimate can't be flagged.
    public static func tasksThatDoNotFit(_ tasks: [TaskItem], longestBlockMinutes: Int) -> [TaskItem] {
        tasks.filter { ($0.effortMinutes ?? 0) > longestBlockMinutes }
    }

    /// How many tasks have no duration, so the load can be understated (an explicit `0` counts as
    /// a duration).
    public static func missingDurations(_ tasks: [TaskItem]) -> Int {
        tasks.filter { $0.effortMinutes == nil }.count
    }

    // MARK: Helpers

    private struct Busy {
        var start: Date
        var end: Date
        var firstTitle: String
        var lastTitle: String
    }

    /// Fixed commitments clipped to the window and merged where they overlap or touch.
    private static func mergedBusyIntervals(_ fixed: [Commitment], from windowStart: Date, to windowEnd: Date) -> [Busy] {
        var clipped: [(start: Date, end: Date, title: String)] = []
        for commitment in fixed.sorted(by: { ($0.start, $0.title) < ($1.start, $1.title) }) {
            let s = max(commitment.start, windowStart)
            let e = min(commitment.start.addingTimeInterval(Double(commitment.minutes) * 60), windowEnd)
            if s < e { clipped.append((s, e, commitment.title)) }
        }
        var merged: [Busy] = []
        for item in clipped {
            if var last = merged.last, item.start <= last.end {
                if item.end >= last.end { last.lastTitle = item.title }   // the one that ends the merged block names the gap after it
                last.end = max(last.end, item.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(Busy(start: item.start, end: item.end, firstTitle: item.title, lastTitle: item.title))
            }
        }
        return merged
    }

    private static func minutes(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }

    private static func block(_ start: Date, _ end: Date, before: String?, after: String?) -> Block {
        Block(start: start, end: end, minutes: minutes(from: start, to: end), before: before, after: after)
    }
}
