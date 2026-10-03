import Foundation
import Testing
@testable import JamaalCore

/// Importance rules and quick dates (docs/schema/task.md).
@MainActor
struct TaskRulesTests {

    // MARK: Medium and high need a date

    @Test func raisingImportanceWithNoDateFillsInTheDefaultAndKeepsAnExistingOne() throws {
        let w = try TaskWorld()
        let undated = w.task("Undated")
        TaskRules.setImportance(undated, to: .high, defaultDueDate: w.d(16))
        #expect(undated.importanceLevel == .high)
        #expect(undated.dueDate == w.d(16).storedDate)

        let dated = w.task("Dated", due: 20)
        TaskRules.setImportance(dated, to: .medium, defaultDueDate: w.d(16))
        #expect(dated.dueDate == w.d(20).storedDate)

        TaskRules.setImportance(dated, to: .low, defaultDueDate: w.d(16))
        #expect(dated.importanceLevel == .low)
        #expect(dated.dueDate == w.d(20).storedDate)                   // lowering never clears the date
    }

    @Test func anImportantOrRepeatingTaskCannotLoseItsDate() throws {
        let w = try TaskWorld()
        let important = w.task("I", due: 16, importance: .high)
        #expect(throws: TaskRuleError.dateRequired) { try TaskRules.setDueDate(important, to: nil) }
        #expect(important.dueDate == w.d(16).storedDate)
        let repeating = w.task("R", due: 16); repeating.repeatMode = .weekly
        #expect(throws: TaskRuleError.dateRequired) { try TaskRules.setDueDate(repeating, to: nil) }
        let plain = w.task("P", due: 16)
        try TaskRules.setDueDate(plain, to: nil)                         // Someday
        #expect(plain.dueDate == nil)
        try TaskRules.setDueDate(plain, to: w.d(18))
        #expect(plain.dueDate == w.d(18).storedDate)
    }

    @Test func anInvariantBrokenByASyncRaceIsNormalisedToToday() throws {
        let w = try TaskWorld()
        let broken = w.task("Broken", importance: .high)                // high, no date
        let repeating = w.task("Repeat"); repeating.repeatMode = .daily
        let fine = w.task("Fine")
        #expect(TaskRules.normalise(broken, today: w.d(15)))
        #expect(TaskRules.normalise(repeating, today: w.d(15)))
        #expect(!TaskRules.normalise(fine, today: w.d(15)))
        #expect(broken.dueDate == w.d(15).storedDate)
        #expect(broken.importanceLevel == .high)                         // intent kept
        #expect(!TaskRules.normalise(broken, today: w.d(15)))            // idempotent
    }

    // MARK: Quick dates (Thu 15 Oct)

    private func dates(_ options: [QuickDate]) -> [String] {
        options.map { "\($0.kind.rawValue):\($0.date?.day.description ?? "none")" }
    }

    @Test func aMondayFirstWeekOffersAllOfThem() throws {
        let w = try TaskWorld()
        let options = QuickDates.options(today: w.d(15), firstWeekday: 1, importance: .low, repeating: false)
        #expect(dates(options) == ["today:15", "tomorrow:16", "laterThisWeek:18", "nextWeek:19", "someday:none"])
    }

    @Test func laterThisWeekIsOnlyOfferedWhileItIsStillInTheCurrentWeek() throws {
        let w = try TaskWorld()
        // Sunday-first: the week is Sun 11 – Sat 17, so three days from Thursday (Sun 18) is next week.
        let sundayFirst = QuickDates.options(today: w.d(15), firstWeekday: 7, importance: .low, repeating: false)
        #expect(dates(sundayFirst) == ["today:15", "tomorrow:16", "nextWeek:18", "someday:none"])
        // Monday-first from Saturday: three days on is Tuesday of next week.
        let saturday = QuickDates.options(today: w.d(17), firstWeekday: 1, importance: .low, repeating: false)
        #expect(!dates(saturday).contains { $0.hasPrefix("laterThisWeek") })
        // Wednesday: three days on is Saturday, still this week.
        let wednesday = QuickDates.options(today: w.d(14), firstWeekday: 1, importance: .low, repeating: false)
        #expect(dates(wednesday).contains("laterThisWeek:17"))
    }

    @Test func somedayIsHiddenForImportantAndRepeatingTasks() throws {
        let w = try TaskWorld()
        for importance in [Importance.medium, .high] {
            let options = QuickDates.options(today: w.d(15), firstWeekday: 1, importance: importance, repeating: false)
            #expect(!options.contains { $0.kind == .someday })
        }
        #expect(!QuickDates.options(today: w.d(15), firstWeekday: 1, importance: .low, repeating: true).contains { $0.kind == .someday })
    }
}
