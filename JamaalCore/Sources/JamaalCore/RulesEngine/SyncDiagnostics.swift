import Foundation
import SwiftData

/// What this device holds for timed habits, as short ids and counts, to compare two devices that disagree about a day's minutes
/// (#279). It never includes a title or a note, so it is safe to paste.
public enum SyncDiagnostics {

    @MainActor
    public static func timedHabitLines(in context: ModelContext, today: CalendarDate) -> [String] {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let windows = (try? context.fetch(FetchDescriptor<HabitTimeWindow>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkSession>())) ?? []

        var lines = ["Records: \(habits.count) habits, \(windows.count) windows, \(entries.count) entries, \(sessions.count) sessions"]

        let timed = windows
            .filter { $0.habit?.kind == "timed" }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        for window in timed {
            let todaysEntries = (window.entries ?? []).filter { CalendarDate(storedDate: $0.date) == today }.map(\.amount).sorted()
            let todaysSessions = (window.sessions ?? []).filter { CalendarDate(storedDate: $0.day) == today }
            let running = todaysSessions.filter { $0.outcome == SessionOutcome.running.rawValue }.count
            let endedMinutes = Int((Double(todaysSessions.filter { $0.outcome != SessionOutcome.running.rawValue }.reduce(0) { $0 + $1.actualSeconds }) / 60).rounded())
            lines.append(
                "Timed window \(shortID(window.id)): entries today [\(todaysEntries.map(String.init).joined(separator: ", "))], "
                + "sessions today \(todaysSessions.count) (\(endedMinutes) min ended, \(running) running)")
        }
        return lines
    }

    private static func shortID(_ id: UUID) -> String { String(id.uuidString.prefix(4)) }
}
