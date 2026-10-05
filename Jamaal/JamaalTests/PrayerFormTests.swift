//
//  PrayerFormTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct PrayerFormTests {
    private let utc = TimeZone(identifier: "UTC")!
    private var boundary: DayBoundary { DayBoundary(rolloverMinute: 0, timeZone: utc) }
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        boundary.instant(of: CalendarDate(year: 2026, month: 10, day: 15)!, atMinute: hour * 60 + minute)
    }
    private let leicester = FoundPlace(name: "Leicester", region: "England, United Kingdom", countryCode: "GB", latitude: 52.6369, longitude: -1.1398)
    private let lahore = FoundPlace(name: "Lahore", region: "Punjab, Pakistan", countryCode: "PK", latitude: 31.5204, longitude: 74.3587)
    private let english = Locale(identifier: "en_GB")

    @Test func aNewFormSuggestsTheMethodForTheDevicesRegion() {
        let form = PrayerForm.new(deviceCountry: "GB")
        #expect(form.draft.method == "moonsightingCommittee")
        #expect(form.suggestionLine(locale: english) == "Suggested for the UK")
        #expect(form.locationLine() == "Choose where")
    }

    @Test func choosingAPlaceFollowsItsCountryUntilTheUserChoosesAMethod() {
        var form = PrayerForm.new(deviceCountry: "GB")
        form.choose(lahore, mode: "manual")
        #expect(form.draft.method == "karachi" && form.draft.madhab == "hanafi")
        #expect(form.suggestionLine(locale: english) == "Suggested for Pakistan")
        form.chooseMethod("egyptian")
        #expect(form.suggestionLine(locale: english) == nil)
        form.choose(leicester, mode: "device")
        #expect(form.draft.method == "egyptian")          // the user's own choice stays
    }

    @Test func aPlaceIsKeptToAboutAKilometreAndNamedForTheDeviceOrACity() {
        var form = PrayerForm.new(deviceCountry: nil)
        form.choose(leicester, mode: "device")
        #expect(form.draft.location?.latitude == 52.64 && form.draft.location?.longitude == -1.14)
        #expect(form.locationLine() == "Leicester · this iPhone")
        form.choose(leicester, mode: "manual")
        #expect(form.locationLine() == "Leicester")
    }

    @Test func aRuleBeingEditedKeepsItsMethodAndShowsNoSuggestion() {
        var draft = PrayerRuleDraft(countryCode: "GB")
        draft.location = leicester.location(mode: "device")
        draft.method = "egyptian"
        let form = PrayerForm(draft: draft, deviceCountry: "GB")
        #expect(form.suggestionLine(locale: english) == nil)
        #expect(form.draft.method == "egyptian")
    }

    @Test func prayersToggleOnAndOff() {
        var form = PrayerForm.new(deviceCountry: nil)
        form.togglePrayer("fajr")
        #expect(!form.isOn("fajr") && form.isOn("isha"))
        form.togglePrayer("fajr")
        #expect(form.isOn("fajr"))
    }

    @Test func theFootnoteSaysWhatWillAppearToday() {
        var form = PrayerForm.new(deviceCountry: "GB")
        #expect(form.footnote(now: at(16, 30), boundary: boundary) == nil)         // no place yet
        form.choose(leicester, mode: "device")
        let note = form.footnote(now: at(16, 30), boundary: boundary)
        #expect(note == "Starting now, today's Asr, Maghrib and Isha will appear. Fajr and Dhuhr have already closed, so they won't be added.")
        #expect(form.footnote(now: at(0, 1), boundary: boundary) == "Today's Fajr, Dhuhr, Asr, Maghrib and Isha will appear.")
        let late = form.footnote(now: at(23, 59), boundary: boundary)
        #expect(late?.contains("have already closed") == true && late?.contains("Tomorrow's will appear") == true)
        form.togglePrayer("fajr"); form.togglePrayer("dhuhr")
        #expect(form.footnote(now: at(16, 30), boundary: boundary) == "Today's Asr, Maghrib and Isha will appear.")
        for p in ["asr", "maghrib", "isha"] { form.togglePrayer(p) }
        #expect(form.footnote(now: at(16, 30), boundary: boundary) == nil)
    }

    @Test func adjustmentsStepByAMinuteWithinAnHourAndZeroClears() {
        var form = PrayerForm.new(deviceCountry: nil)
        form.stepAdjustment("fajr", by: 1); form.stepAdjustment("fajr", by: 1)
        #expect(form.draft.adjustments == ["fajr": 2])
        form.stepAdjustment("fajr", by: -2)
        #expect(form.draft.adjustments.isEmpty)
        for _ in 0..<70 { form.stepAdjustment("isha", by: -1) }
        #expect(form.draft.adjustments["isha"] == -60)
        #expect(PrayerForm.adjustment(2) == "+2 min" && PrayerForm.adjustment(-3) == "−3 min" && PrayerForm.adjustment(0) == "None")
    }

    @Test func theAdvancedRowSummarisesWhatIsSet() {
        var form = PrayerForm.new(deviceCountry: nil)
        #expect(form.advancedSummary == "Adjustments, high latitude")
        form.draft.highLatitude = "seventhOfNight"
        #expect(form.advancedSummary == "Seventh of the night")
        form.stepAdjustment("fajr", by: 1)
        #expect(form.advancedSummary == "1 adjusted")
        #expect(PrayerForm.ishaEndsTitle("midnight") == "Islamic midnight" && PrayerForm.ishaEndsTitle("fajr") == "Fajr")
    }

    @Test func everyRefusalHasACalmSentence() {
        for error in [PrayerEditError.emptyTitle, .noPrayers, .unknownPrayer, .unknownMethod, .unknownOption, .noLocation, .adjustmentOutOfRange] {
            #expect(!PrayerForm.message(for: error).isEmpty)
        }
        #expect(PrayerForm.message(for: .noLocation).hasPrefix("Choose where"))
    }
}
