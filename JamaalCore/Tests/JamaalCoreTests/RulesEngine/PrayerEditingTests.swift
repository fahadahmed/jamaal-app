import Foundation
import SwiftData
import Testing
@testable import JamaalCore

/// The prayer times rule (docs/schema/anchor.md, AN-04 and AN-11). Leicester, 52.6369 N, 1.1398 W.
@MainActor
struct PrayerEditingTests {

    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func d(_ day: Int) -> CalendarDate { CalendarDate(year: 2026, month: 10, day: day)! }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { boundary.instant(of: d(day), atMinute: hour * 60 + minute) }
    private func context() throws -> ModelContext { ModelContext(try JamaalSchema.makeContainer(inMemory: true)) }
    private let leicester = PrayerConfig.Location(mode: "device", latitude: 52.64, longitude: -1.14, name: "Leicester")

    private func draft(country: String? = "GB") -> PrayerRuleDraft {
        var p = PrayerRuleDraft(countryCode: country)
        p.location = leicester
        return p
    }
    private func create(_ draft: PrayerRuleDraft, _ c: ModelContext) throws -> AnchorRule { try PrayerEditing.create(draft, in: c, now: at(15, 9)) }
    private func config(_ rule: AnchorRule) throws -> PrayerConfig {
        guard case .prayer(let config) = rule.config else { throw AnchorEditError.notAScheduledRule }
        return config
    }

    // MARK: Defaults and suggestions

    @Test func theDefaultsAreFivePrayersIslamicMidnightJumuahAndAReminderAtTheStart() {
        let p = PrayerRuleDraft(countryCode: nil)
        #expect(p.title == "Salah")
        #expect(p.prayers == ["fajr", "dhuhr", "asr", "maghrib", "isha"])
        #expect(p.ishaEnds == "midnight")
        #expect(p.fridayLabel)
        #expect(p.effortMinutes == 10)
        #expect(p.remindAtStart)
        #expect(p.remindBeforeEndMinutes == nil)
        #expect(p.location == nil)
        #expect(p.method == "muslimWorldLeague" && p.madhab == "shafi")
    }

    @Test func theCountryPreselectsMethodAndMadhab() {
        #expect(PrayerRuleDraft(countryCode: "GB").method == "moonsightingCommittee")
        #expect(PrayerRuleDraft(countryCode: "pk").method == "karachi")
        #expect(PrayerRuleDraft(countryCode: "pk").madhab == "hanafi")
        #expect(PrayerRuleDraft(countryCode: "SA").method == "ummAlQura")
        var p = PrayerRuleDraft(countryCode: nil)
        p.applySuggestion(forCountry: "TR")
        #expect(p.method == "turkey" && p.madhab == "hanafi")
    }

    @Test func everyOfferedMethodComputesTimesAtLeicester() {
        #expect(PrayerMethods.all.count == 12)
        for item in PrayerMethods.all {
            var config = PrayerConfig(); config.method = item.key; config.location = leicester
            #expect(PrayerWindows.windows(config: config, on: d(15)).count == 5, "\(item.key)")
            #expect(!item.title.isEmpty)
        }
        #expect(PrayerMethods.title(for: "moonsightingCommittee") == "Moonsighting Committee")
        #expect(PrayerMethods.title(for: "nonsense") == "Muslim World League")
    }

    // MARK: Creating

    @Test func creatingWritesAFixedPrayerRuleWithItsConfig() throws {
        let c = try context()
        let rule = try create(draft(), c)
        #expect(rule.title == "Salah")
        #expect(rule.source == .prayerWindow)
        #expect(rule.placementKind == .fixed)
        #expect(rule.effortMinutes == 10)
        #expect(rule.createdAt == at(15, 9))
        let cfg = try config(rule)
        #expect(cfg.method == "moonsightingCommittee" && cfg.madhab == "shafi")
        #expect(cfg.location == leicester)
        #expect(cfg.reminder == AnchorReminder(atStart: true, beforeEndMinutes: nil))
        #expect(cfg.prayers.count == 5 && cfg.fridayLabel && cfg.ishaEnds == "midnight")
    }

    @Test func theChosenPrayersAdjustmentsAndOptionsAreKept() throws {
        let c = try context()
        var p = draft()
        p.prayers = ["asr", "maghrib", "isha"]
        p.madhab = "hanafi"; p.ishaEnds = "fajr"; p.fridayLabel = false; p.highLatitude = "seventhOfNight"
        p.adjustments = ["fajr": -3, "isha": 5]
        p.remindAtStart = false; p.remindBeforeEndMinutes = 10
        let cfg = try config(try create(p, c))
        #expect(cfg.prayers == ["asr", "maghrib", "isha"])
        #expect(cfg.madhab == "hanafi" && cfg.ishaEnds == "fajr" && !cfg.fridayLabel && cfg.highLatitude == "seventhOfNight")
        #expect(cfg.adjustmentsMinutes == ["fajr": -3, "isha": 5])
        #expect(cfg.reminder == AnchorReminder(atStart: false, beforeEndMinutes: 10))
        var none = draft(); none.remindAtStart = false
        #expect(try config(try create(none, c)).reminder == nil)
    }

    @Test func prayersAreStoredInTheirDayOrderWhateverOrderTheyWerePicked() throws {
        let c = try context()
        var p = draft(); p.prayers = ["isha", "fajr", "asr"]
        #expect(try config(try create(p, c)).prayers == ["fajr", "asr", "isha"])
    }

    // MARK: Refusals

    @Test func eachMistakeIsRefusedAndWritesNothing() throws {
        let c = try context()
        var blank = draft(); blank.title = " "
        #expect(throws: PrayerEditError.emptyTitle) { try create(blank, c) }
        var none = draft(); none.prayers = []
        #expect(throws: PrayerEditError.noPrayers) { try create(none, c) }
        var odd = draft(); odd.prayers = ["fajr", "tahajjud"]
        #expect(throws: PrayerEditError.unknownPrayer) { try create(odd, c) }
        var method = draft(); method.method = "nonsense"
        #expect(throws: PrayerEditError.unknownMethod) { try create(method, c) }
        var madhab = draft(); madhab.madhab = "maliki"
        #expect(throws: PrayerEditError.unknownOption) { try create(madhab, c) }
        var ends = draft(); ends.ishaEnds = "never"
        #expect(throws: PrayerEditError.unknownOption) { try create(ends, c) }
        var nowhere = draft(); nowhere.location = nil
        #expect(throws: PrayerEditError.noLocation) { try create(nowhere, c) }
        var off = draft(); off.location = PrayerConfig.Location(mode: "manual", latitude: 120, longitude: 0, name: nil)
        #expect(throws: PrayerEditError.noLocation) { try create(off, c) }
        var big = draft(); big.adjustments = ["fajr": 90]
        #expect(throws: PrayerEditError.adjustmentOutOfRange) { try create(big, c) }
        #expect(try c.fetchCount(FetchDescriptor<AnchorRule>()) == 0)
    }

    // MARK: Editing

    @Test func aDraftFromAPrayerRuleCarriesItsFields() throws {
        let c = try context()
        var p = draft(); p.madhab = "hanafi"; p.adjustments = ["dhuhr": 2]
        let rule = try create(p, c)
        let back = try #require(PrayerRuleDraft(editing: rule))
        #expect(back.title == "Salah" && back.location == leicester && back.madhab == "hanafi" && back.adjustments == ["dhuhr": 2])
        let scheduled = try AnchorEditing.create(AnchorRuleDraft.preset(.schoolRun, today: d(15)), in: c, now: at(15, 9))
        #expect(PrayerRuleDraft(editing: scheduled) == nil)
    }

    @Test func editingChangesTheRuleButKeepsItsExceptions() throws {
        let c = try context()
        let rule = try create(draft(), c)
        try AnchorEditing.addException(to: rule, from: d(20), to: d(24), reason: .travel)
        var p = try #require(PrayerRuleDraft(editing: rule))
        p.method = "northAmerica"; p.prayers = ["fajr", "maghrib"]
        try PrayerEditing.update(rule, with: p)
        let cfg = try config(rule)
        #expect(cfg.method == "northAmerica" && cfg.prayers == ["fajr", "maghrib"])
        #expect(cfg.exceptions.count == 1)
    }

    @Test func aFailedEditChangesNothing() throws {
        let c = try context()
        let rule = try create(draft(), c)
        var p = try #require(PrayerRuleDraft(editing: rule))
        p.prayers = []
        #expect(throws: PrayerEditError.noPrayers) { try PrayerEditing.update(rule, with: p) }
        #expect(try config(rule).prayers.count == 5)
    }

    @Test func aPrayerRuleCanHaveBreaksToo() throws {
        let c = try context()
        let rule = try create(draft(), c)
        try AnchorEditing.addException(to: rule, from: d(20), to: d(22), reason: .illness)
        try AnchorEditing.addException(to: rule, from: d(21), to: d(25), reason: .illness)
        #expect(try config(rule).exceptions.count == 1)
        try AnchorEditing.removeException(from: rule, at: 0)
        #expect(try config(rule).exceptions.isEmpty)
        let broken = AnchorRule(title: "X"); broken.configData = "nonsense"; c.insert(broken)
        #expect(throws: AnchorEditError.notAScheduledRule) { try AnchorEditing.addException(to: broken, from: d(20), to: nil, reason: .other) }
    }

    // MARK: Location

    @Test func aCoordinateIsKeptToAboutAKilometre() {
        let l = PrayerLocationRules.coarse(mode: "device", latitude: 52.636912, longitude: -1.139832, name: "Leicester")
        #expect(l.latitude == 52.64 && l.longitude == -1.14)
        #expect(l.mode == "device" && l.name == "Leicester")
        #expect(PrayerLocationRules.coarse(mode: "manual", latitude: -33.8688, longitude: 151.2093, name: nil).latitude == -33.87)
    }

    @Test func distancesAreInKilometres() {
        let nottingham = PrayerConfig.Location(mode: "device", latitude: 52.95, longitude: -1.15, name: nil)
        let km = PrayerLocationRules.kilometres(from: leicester, to: nottingham)
        #expect(km > 33 && km < 37)
        #expect(PrayerLocationRules.kilometres(from: leicester, to: leicester) == 0)
    }

    @Test func aDeviceOnlyMovesTheStoredPlaceWhenItHasMovedAboutTwentyFiveKilometres() {
        let near = PrayerConfig.Location(mode: "device", latitude: 52.68, longitude: -1.14, name: "Next door")      // about 4 km
        let far = PrayerConfig.Location(mode: "device", latitude: 52.95, longitude: -1.15, name: "Nottingham")      // about 35 km
        #expect(PrayerLocationRules.updatedPlace(stored: leicester, device: near) == nil)
        #expect(PrayerLocationRules.updatedPlace(stored: leicester, device: far) == far)
        #expect(PrayerLocationRules.updatedPlace(stored: nil, device: near) == near)                                 // nothing stored yet
    }

    @Test func aChosenCityNeverFollowsTheDevice() {
        var manual = leicester; manual.mode = "manual"
        let far = PrayerConfig.Location(mode: "device", latitude: 52.95, longitude: -1.15, name: "Nottingham")
        #expect(PrayerLocationRules.updatedPlace(stored: manual, device: far) == nil)
    }

    @Test func aDeviceRuleFollowsTheDeviceOnlyWhenItHasMoved() throws {
        let c = try context()
        let rule = try create(draft(), c)
        let near = PrayerConfig.Location(mode: "device", latitude: 52.68, longitude: -1.14, name: "Next door")
        let far = PrayerConfig.Location(mode: "device", latitude: 52.95, longitude: -1.15, name: "Nottingham")
        #expect(!PrayerEditing.followDevice(rule, reading: near))
        #expect(try config(rule).location == leicester)
        #expect(PrayerEditing.followDevice(rule, reading: far))
        #expect(try config(rule).location == far)
        var manual = draft(); manual.location?.mode = "manual"
        let chosen = try create(manual, c)
        #expect(!PrayerEditing.followDevice(chosen, reading: far))
        let broken = AnchorRule(title: "X"); broken.configData = "nonsense"; c.insert(broken)
        #expect(!PrayerEditing.followDevice(broken, reading: far))
    }

    // MARK: Today

    @Test func theFormSaysWhichOfTodaysPrayersWillAppear() throws {
        let remaining = PrayerEditing.upcomingToday(draft(), now: at(15, 0, 1), boundary: boundary)
        #expect(remaining.map(\.prayer) == ["fajr", "dhuhr", "asr", "maghrib", "isha"])
        let evening = PrayerEditing.upcomingToday(draft(), now: at(15, 23, 59), boundary: boundary)
        #expect(evening.isEmpty)
        var asrOnward = draft(); asrOnward.prayers = ["fajr", "asr"]
        #expect(PrayerEditing.upcomingToday(asrOnward, now: at(15, 12), boundary: boundary).map(\.prayer) == ["asr"])
        var nowhere = draft(); nowhere.location = nil
        #expect(PrayerEditing.upcomingToday(nowhere, now: at(15, 0, 1), boundary: boundary).isEmpty)
    }
}
