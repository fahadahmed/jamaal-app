import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// Prayer windows (docs/schema/anchor.md): Fajr → sunrise · Dhuhr → Asr · Asr → Maghrib ·
/// Maghrib → Isha · Isha → Islamic midnight (or the next Fajr). Times come from `adhan-swift`,
/// computed on-device from date, location and these settings.
@MainActor
struct PrayerWindowsTests {

    private let newYork = TimeZone(identifier: "America/New_York")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: newYork) }
    /// Raleigh, North Carolina: the library's own test location.
    private let raleigh = PrayerConfig.Location(mode: "manual", latitude: 35.7750, longitude: -78.6336, name: "Raleigh")

    private func config(
        method: String = "northAmerica", madhab: String = "hanafi", ishaEnds: String = "midnight",
        friday: Bool = true, prayers: [String] = ["fajr", "dhuhr", "asr", "maghrib", "isha"],
        adjustments: [String: Int] = [:], location: PrayerConfig.Location? = nil, highLatitude: String = "middleOfNight"
    ) -> PrayerConfig {
        PrayerConfig(
            version: 1, method: method, madhab: madhab, highLatitude: highLatitude, ishaEnds: ishaEnds, fridayLabel: friday,
            reminder: nil, prayers: prayers, adjustmentsMinutes: adjustments, location: location ?? raleigh, exceptions: []
        )
    }

    private func windows(_ config: PrayerConfig, _ day: CalendarDate) -> [PrayerWindow] {
        PrayerWindows.windows(config: config, on: day)
    }

    private func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = newYork
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private let sunday = CalendarDate(year: 2015, month: 7, day: 12)!
    private let friday = CalendarDate(year: 2015, month: 7, day: 10)!

    // MARK: Times and windows (the library's published vector: North America, Hanafi, 12 Jul 2015)

    @Test func startsMatchThePublishedTimes() throws {
        let w = windows(config(), sunday)
        #expect(w.map(\.prayer) == ["fajr", "dhuhr", "asr", "maghrib", "isha"])
        #expect(w.map { clock($0.start) } == ["4:42 AM", "1:21 PM", "6:22 PM", "8:32 PM", "9:57 PM"])
    }

    @Test func eachWindowRunsToTheNextPrayersStartAndFajrEndsAtSunrise() throws {
        let w = windows(config(), sunday)
        #expect(clock(w[0].end) == "6:08 AM")                   // Fajr → sunrise
        #expect(w[1].end == w[2].start)                          // Dhuhr → Asr
        #expect(w[2].end == w[3].start)                          // Asr → Maghrib
        #expect(w[3].end == w[4].start)                          // Maghrib → Isha
        #expect(w.allSatisfy { $0.start < $0.end })
    }

    @Test func ishaEndsAtIslamicMidnightByDefaultAfterCivilMidnightInSummer() throws {
        let isha = try #require(windows(config(), sunday).last)
        let comps = Calendar(identifier: .gregorian).dateComponents(in: newYork, from: isha.end)
        #expect(comps.day == 13)                                 // after civil midnight
        #expect(comps.hour == 0)
        #expect((30...45).contains(comps.minute ?? -1))          // midway between Maghrib (8:32 PM) and the next Fajr (~4:43 AM)
    }

    @Test func ishaCanEndAtTheNextFajrInstead() throws {
        let isha = try #require(windows(config(ishaEnds: "fajr"), sunday).last)
        #expect(clock(isha.end).hasSuffix("AM"))
        let midnight = try #require(windows(config(), sunday).last)
        #expect(isha.end > midnight.end)
    }

    // MARK: Settings

    @Test func theHanafiAsrIsLaterThanTheStandardAsr() throws {
        let hanafi = try #require(windows(config(madhab: "hanafi"), sunday).first { $0.prayer == "asr" })
        let shafi = try #require(windows(config(madhab: "shafi"), sunday).first { $0.prayer == "asr" })
        #expect(hanafi.start > shafi.start)
    }

    @Test func aPrayersAdjustmentMovesItsStartAndTheWindowsAroundIt() throws {
        let base = windows(config(), sunday)
        let moved = windows(config(adjustments: ["asr": 5, "fajr": -3]), sunday)
        #expect(moved[2].start == base[2].start.addingTimeInterval(5 * 60))          // Asr later
        #expect(moved[1].end == moved[2].start)                                       // so Dhuhr's window ends later too
        #expect(moved[0].start == base[0].start.addingTimeInterval(-3 * 60))
        #expect(moved[3].start == base[3].start)                                      // untouched
    }

    @Test func onlyTheChosenPrayersAreGenerated() {
        #expect(windows(config(prayers: ["fajr", "isha"]), sunday).map(\.prayer) == ["fajr", "isha"])
    }

    @Test func fridaysDhuhrIsTitledJumuahOnlyWhenTheLabelIsOn() throws {
        let on = try #require(windows(config(friday: true), friday).first { $0.prayer == "dhuhr" })
        let off = try #require(windows(config(friday: false), friday).first { $0.prayer == "dhuhr" })
        let other = try #require(windows(config(friday: true), sunday).first { $0.prayer == "dhuhr" })
        #expect(on.title == "Jumu'ah")
        #expect(on.prayer == "dhuhr")                            // same key, so history stays linked
        #expect(off.title == "Dhuhr")
        #expect(other.title == "Dhuhr")
        #expect(windows(config(), sunday).map(\.title) == ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"])
    }

    @Test func anUnknownOrCustomMethodFallsBackToTheMuslimWorldLeague() throws {
        let fallback = windows(config(method: "muslimWorldLeague", madhab: "shafi"), sunday)
        #expect(windows(config(method: "futuristic", madhab: "shafi"), sunday).map(\.start) == fallback.map(\.start))
        #expect(windows(config(method: "other", madhab: "shafi"), sunday).map(\.start) == fallback.map(\.start))
    }

    @Test func withNoLocationThereAreNoWindows() {
        var c = config()
        c.location = nil
        #expect(PrayerWindows.windows(config: c, on: sunday).isEmpty)
    }

    @Test func aDifferentLocationGivesDifferentTimes() throws {
        let auckland = PrayerConfig.Location(mode: "manual", latitude: -36.85, longitude: 174.76, name: "Auckland")
        let a = windows(config(location: auckland), sunday)
        let b = windows(config(), sunday)
        #expect(a.map(\.start) != b.map(\.start))
        #expect(a.count == 5)
    }

    // MARK: Generation through the same preview and sync

    private func rule(_ w: AnchorWorld, _ config: PrayerConfig, createdAt: Date? = nil) -> AnchorRule {
        let rule = AnchorRule(title: "Salah")
        rule.source = .prayerWindow
        rule.configData = config.json
        rule.effortMinutes = 10
        rule.createdAt = createdAt ?? w.at(1, 0)
        w.context.insert(rule)
        return rule
    }

    @Test func aPrayerRuleGeneratesFivePerDayForTodayAndTomorrow() throws {
        let w = try AnchorWorld(timeZone: "America/New_York")
        let r = rule(w, config())
        let today = CalendarDate(year: 2015, month: 7, day: 12)!
        r.createdAt = w.boundary.startInstant(of: today.addingDays(-5))
        let now = w.boundary.instant(of: today, atMinute: 3 * 60)
        let report = try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: now)
        #expect(report.created == 10)
        let anchors = try w.anchors()
        #expect(anchors.map(\.slotKey) == ["fajr", "dhuhr", "asr", "maghrib", "isha"] + ["fajr", "dhuhr", "asr", "maghrib", "isha"])
        #expect(anchors.allSatisfy { $0.effortMinutes == 10 })
        #expect(anchors.allSatisfy { $0.remindBeforeStartMinutes == 0 })     // prayer times remind at the start by default
        #expect(anchors.allSatisfy { $0.remindBeforeEndMinutes == nil })
        #expect(try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: now) == AnchorSyncReport())
    }

    @Test func ishaAfterMidnightStillBelongsToTheDayItStarts() throws {
        let w = try AnchorWorld(timeZone: "America/New_York")
        let r = rule(w, config())
        let today = CalendarDate(year: 2015, month: 7, day: 12)!
        r.createdAt = w.boundary.startInstant(of: today.addingDays(-5))
        _ = try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: w.boundary.instant(of: today, atMinute: 180))
        let isha = try #require(try w.anchors().first { $0.slotKey == "isha" && $0.occurrenceDate == today.storedDate })
        #expect(w.boundary.logicalDate(at: isha.windowEnd) == today.addingDays(1))
    }

    @Test func windowsThatClosedBeforeTheRuleExistedAreNotGenerated() throws {
        let w = try AnchorWorld(timeZone: "America/New_York")
        let today = CalendarDate(year: 2015, month: 7, day: 12)!
        let afternoon = w.boundary.instant(of: today, atMinute: 14 * 60 + 5)               // 2:05 PM, after Dhuhr began
        _ = rule(w, config(), createdAt: afternoon)
        _ = try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: afternoon)
        let todays = try w.anchors().filter { $0.occurrenceDate == today.storedDate }.map(\.slotKey)
        #expect(todays == ["dhuhr", "asr", "maghrib", "isha"])                              // Fajr's window (to sunrise) had closed; Dhuhr's is still open
    }

    @Test func anExceptionRemovesTheDaysPrayers() throws {
        let w = try AnchorWorld(timeZone: "America/New_York")
        let today = CalendarDate(year: 2015, month: 7, day: 12)!
        var c = config()
        c.exceptions = [AnchorException(from: today.addingDays(1), to: today.addingDays(1), reason: "travel")]
        let r = rule(w, c)
        r.createdAt = w.boundary.startInstant(of: today.addingDays(-5))
        _ = try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: w.boundary.instant(of: today, atMinute: 180))
        #expect(try w.anchors().count == 5)
        #expect(try w.anchors().allSatisfy { $0.occurrenceDate == today.storedDate })
    }

    @Test func changingAnAdjustmentUpdatesPendingPrayersInPlaceButNeverDecidedOnes() throws {
        let w = try AnchorWorld(timeZone: "America/New_York")
        let today = CalendarDate(year: 2015, month: 7, day: 12)!
        let r = rule(w, config())
        r.createdAt = w.boundary.startInstant(of: today.addingDays(-5))
        let now = w.boundary.instant(of: today, atMinute: 180)
        _ = try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: now)
        let before = Dictionary(uniqueKeysWithValues: try w.anchors().map { ("\($0.occurrenceDate.timeIntervalSince1970)|\($0.slotKey)", $0.windowStart) })
        let asr = try #require(try w.anchors().first { $0.slotKey == "asr" && $0.occurrenceDate == today.storedDate })
        asr.status = .skipped
        r.configData = config(adjustments: ["asr": 5]).json
        let report = try AnchorGenerator.sync(in: w.context, boundary: w.boundary, now: now)
        // Asr starts 5 minutes later, which also ends Dhuhr's window later: today's Dhuhr, and tomorrow's Dhuhr and Asr.
        #expect(report.updated == 3)
        #expect(asr.windowStart == before["\(asr.occurrenceDate.timeIntervalSince1970)|asr"])      // decided: untouched
        #expect(try w.anchors().count == 10)
    }
}

/// The bundled country → method suggestion table (docs/schema/anchor.md, "Prayer method suggestion").
struct PrayerMethodSuggestionTests {

    @Test(arguments: [
        ("US", "moonsightingCommittee", "shafi"), ("CA", "moonsightingCommittee", "shafi"), ("GB", "moonsightingCommittee", "shafi"),
        ("SA", "ummAlQura", "shafi"), ("AE", "dubai", "shafi"), ("KW", "kuwait", "shafi"), ("QA", "qatar", "shafi"),
        ("SG", "singapore", "shafi"), ("MY", "singapore", "shafi"), ("ID", "singapore", "shafi"),
        ("TR", "turkey", "hanafi"), ("IR", "tehran", "shafi"), ("EG", "egyptian", "shafi"),
        ("PK", "karachi", "hanafi"), ("IN", "karachi", "hanafi"), ("BD", "karachi", "hanafi"), ("AF", "karachi", "hanafi"),
        ("NZ", "muslimWorldLeague", "shafi"), ("DE", "muslimWorldLeague", "shafi"),
    ])
    func eachCountryGetsItsDocumentedSuggestion(code: String, method: String, madhab: String) {
        let suggestion = PrayerMethodSuggestion.forCountry(code)
        #expect(suggestion.method == method)
        #expect(suggestion.madhab == madhab)
    }

    @Test func codesAreCaseInsensitiveAndUnknownOrMissingFallBack() {
        #expect(PrayerMethodSuggestion.forCountry("tr").method == "turkey")
        #expect(PrayerMethodSuggestion.forCountry(" Pk ").madhab == "hanafi")
        #expect(PrayerMethodSuggestion.forCountry(nil).method == "muslimWorldLeague")
        #expect(PrayerMethodSuggestion.forCountry("").method == "muslimWorldLeague")
    }

    @Test func everySuggestedMethodIsOneThePrayerLibraryOffers() {
        let offered: Set<String> = ["muslimWorldLeague", "egyptian", "karachi", "ummAlQura", "dubai", "moonsightingCommittee",
                                    "northAmerica", "kuwait", "qatar", "singapore", "tehran", "turkey"]
        for code in ["US", "SA", "AE", "KW", "QA", "SG", "TR", "IR", "EG", "PK", "NZ"] {
            #expect(offered.contains(PrayerMethodSuggestion.forCountry(code).method))
        }
    }
}
