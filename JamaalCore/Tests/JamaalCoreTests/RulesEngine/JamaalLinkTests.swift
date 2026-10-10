import Foundation
import Testing
@testable import JamaalCore

/// The links a widget (and later the watch) opens the app with (docs/architecture/widgets-and-watch.md, "Opening the app"):
/// the same routes a notification tap uses, so there is one path in.
struct JamaalLinkTests {

    private let today = CalendarDate(year: 2026, month: 10, day: 15)!
    private func route(_ string: String) -> NotificationRoute? {
        JamaalLink.route(from: URL(string: string)!, today: today)
    }

    @Test func todayOpensToday() {
        #expect(route("jamaal://today") == .today)
    }

    @Test func planOpensTomorrowsPlan() {
        #expect(route("jamaal://plan") == .planning(CalendarDate(year: 2026, month: 10, day: 16)!))
    }

    @Test func planAtTheEndOfAMonthRollsOver() {
        let eom = CalendarDate(year: 2026, month: 10, day: 31)!
        #expect(JamaalLink.route(from: URL(string: "jamaal://plan")!, today: eom) == .planning(CalendarDate(year: 2026, month: 11, day: 1)!))
    }

    @Test func aTaskLinkCarriesTheTasksId() {
        let id = UUID()
        #expect(route("jamaal://task/\(id.uuidString)") == .task(id))
        #expect(route("jamaal://task/\(id.uuidString.lowercased())") == .task(id), "case doesn't matter")
    }

    @Test func theSchemeAndHostIgnoreCase() {
        #expect(route("JAMAAL://Today") == .today)
    }

    @Test func aTrailingSlashIsFine() {
        #expect(route("jamaal://today/") == .today)
    }

    @Test(arguments: [
        "jamaal://task", "jamaal://task/", "jamaal://task/not-a-uuid", "jamaal://nowhere", "jamaal://",
        "https://example.com/today", "other://today", "jamaal://today/extra/parts",
    ])
    func anythingElseIsIgnoredNotGuessedAt(_ link: String) {
        #expect(route(link) == nil)
    }

    @Test func aLinkMakesItsOwnURLAndComesBack() {
        let id = UUID()
        for link in [JamaalLink.today, .plan, .task(id)] {
            #expect(JamaalLink.route(from: link.url, today: today) == link.route(today: today))
        }
        #expect(JamaalLink.task(id).url.absoluteString == "jamaal://task/\(id.uuidString)")
    }
}
