import Foundation

/// Module 7, the next gap: how Today can say "focus on this between the anchors". It reuses the free blocks Night Planning already measures
/// (`FreeTime`): the next block of 20 minutes or more that **ends at a fixed commitment**, and the first task in Today's order that fits it.
/// A gap that only ends with the working day is not a gap before anything, and a gap nothing fits is not worth a line, so neither is shown.
/// Nothing here blocks anything: it only points.
public struct NextGap {
    public var start: Date
    public var end: Date
    public var minutes: Int
    /// The fixed commitment this gap ends at ("Asr").
    public var before: String
    /// The gap has begun: it is free right now, rather than free after the Anchor that is on.
    public var startsNow: Bool
    public var task: TaskItem

    /// - Parameter tasks: the tasks Today shows, **in Today's order**; the first one whose estimate fits is offered. Done tasks and tasks
    ///   with no estimate are never offered (an unknown length can't be said to fit).
    public static func find(
        now: Date, today: CalendarDate, boundary: DayBoundary, dayStartMinute: Int, dayEndMinute: Int,
        anchors: [Anchor], tasks: [TaskItem]
    ) -> NextGap? {
        let free = FreeTime.compute(
            day: today, boundary: boundary, dayStartMinute: dayStartMinute, dayEndMinute: dayEndMinute, now: now,
            commitments: FreeTime.commitments(from: anchors), habitMinutes: 0)
        guard let block = free.visibleBlocks.first(where: { $0.before != nil }), let before = block.before else { return nil }
        let candidate = tasks.first { task in
            guard !task.isCompleted, task.droppedAt == nil, let effort = task.effortMinutes, effort > 0 else { return false }
            return effort <= block.minutes
        }
        guard let candidate else { return nil }
        return NextGap(start: block.start, end: block.end, minutes: block.minutes, before: before,
                       startsNow: block.start <= now.addingTimeInterval(60), task: candidate)
    }
}
