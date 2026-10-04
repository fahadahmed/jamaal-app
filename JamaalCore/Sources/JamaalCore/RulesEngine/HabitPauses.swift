import Foundation

/// One pause: a date range when a habit is paused (docs/schema/habit.md, "Pauses").
///
/// `to == nil` is open-ended, until the user resumes. The reason is for display only; an
/// unrecognised one is kept as its raw string so a newer app's value survives a round trip.
public struct HabitPause: Equatable, Sendable, Codable {
    public var from: CalendarDate
    public var to: CalendarDate?
    public var reason: String

    public init(from: CalendarDate, to: CalendarDate?, reason: PauseReason) {
        self.from = from
        self.to = to
        self.reason = reason.storable ?? PauseReason.other.rawValue
    }

    public var reasonKind: PauseReason { PauseReason(stored: reason) }

    /// Whether `day` falls inside the pause, both ends included.
    public func covers(_ day: CalendarDate) -> Bool {
        from <= day && (to.map { day <= $0 } ?? true)
    }

    private enum CodingKeys: String, CodingKey { case from, to, reason }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = try c.decode(CalendarDate.self, forKey: .from)
        to = try c.decodeIfPresent(CalendarDate.self, forKey: .to)
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? PauseReason.other.rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(from, forKey: .from)
        if let to { try c.encode(to, forKey: .to) } else { try c.encodeNil(forKey: .to) }
        try c.encode(reason, forKey: .reason)
    }
}

public enum HabitPauseError: Error, Equatable, Sendable {
    case endsBeforeItStarts
}

/// Reads and writes `Habit.pausesData`, a JSON list.
public enum HabitPauses {

    /// Pauses a habit from `from` until `until` (`nil`: until it is resumed). A pause that overlaps an earlier one
    /// is merged into it. Paused days are unscheduled: no cell fills, nothing counts against the habit.
    public static func pause(_ habit: Habit, from: CalendarDate, until: CalendarDate?, reason: PauseReason) throws {
        if let until, until < from { throw HabitPauseError.endsBeforeItStarts }
        var merged = HabitPause(from: from, to: until, reason: reason)
        var kept: [HabitPause] = []
        for existing in habit.pauses {
            let overlaps = (existing.to.map { merged.from <= $0 } ?? true) && (merged.to.map { existing.from <= $0 } ?? true)
            if overlaps {
                let start = min(existing.from, merged.from)
                let end: CalendarDate? = (existing.to == nil || merged.to == nil) ? nil : max(existing.to!, merged.to!)
                merged = HabitPause(from: start, to: end, reason: existing.from <= from ? existing.reasonKind : reason)
            } else {
                kept.append(existing)
            }
        }
        habit.pauses = (kept + [merged]).sorted { $0.from < $1.from }
    }

    /// Resumes on `day`: the pause covering it ends the day before, or goes if it hadn't started before `day`.
    public static func resume(_ habit: Habit, on day: CalendarDate) {
        var pauses = habit.pauses
        guard let index = pauses.firstIndex(where: { $0.covers(day) }) else { return }
        if pauses[index].from < day {
            pauses[index].to = day.addingDays(-1)
        } else {
            pauses.remove(at: index)
        }
        habit.pauses = pauses
    }

    /// The pause covering `day`, if any.
    public static func active(_ habit: Habit, on day: CalendarDate) -> HabitPause? {
        habit.pauses.first { $0.covers(day) }
    }

    /// The pauses in `json`; an empty or unreadable value means none.
    public static func decode(_ json: String) -> [HabitPause] {
        guard let data = json.data(using: .utf8),
              let pauses = try? JSONDecoder().decode([HabitPause].self, from: data) else { return [] }
        return pauses
    }

    public static func encode(_ pauses: [HabitPause]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(pauses), let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }
}

extension Habit {
    /// Typed view of `pausesData`.
    public var pauses: [HabitPause] {
        get { HabitPauses.decode(pausesData) }
        set { pausesData = HabitPauses.encode(newValue) }
    }

    /// Whether the habit is paused on `day`.
    public func isPaused(on day: CalendarDate) -> Bool {
        pauses.contains { $0.covers(day) }
    }

    /// The ISO weekdays (Monday = 1 … Sunday = 7) in `scheduledDays`; anything unparseable is ignored.
    public var scheduledWeekdays: Set<Int> {
        Set(scheduledDays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.filter { (1...7).contains($0) })
    }
}
