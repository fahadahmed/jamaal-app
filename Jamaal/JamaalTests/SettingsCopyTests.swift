//
//  SettingsCopyTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

struct SettingsCopyTests {

    @Test func theHomeRowSummarisesTheNormalDayAndTheWorkingDay() {
        let settings = UserSettings()
        #expect(SettingsCopy.capacitySummary(settings) == "3h · 08:00–19:00")
        settings.mediumDayMinutes = 165; settings.dayStartMinute = 9 * 60 + 30; settings.dayEndMinute = 17 * 60
        #expect(SettingsCopy.capacitySummary(settings) == "2h 45m · 09:30–17:00")
    }

    @Test func lowAndHighAreRoundedToFiveMinutes() {
        #expect(SettingsCopy.levels(mediumDayMinutes: 180) == "Low is 2h, high is 4h.")
        #expect(SettingsCopy.levels(mediumDayMinutes: 205) == "Low is 2h 15m, high is 4h 35m.")
    }

    @Test func theSuggestionAndThePlanningNoteReadAsInTheFrame() {
        #expect(SettingsCopy.suggestion(160) == "You usually do about 2h 40m — set your normal day to that?")
        #expect(SettingsCopy.planningNote(planningMinute: 18 * 60 + 30)
                == "Planning is at 18:30, before the working day ends. That's fine; tonight's review will show the day so far.")
    }

    @Test func theRolloverNoteSaysWhenItCanChange() {
        #expect(SettingsCopy.rolloverNote(.after(180)) == "Can change after 03:00 today")
        #expect(SettingsCopy.rolloverNote(.upTo(600)) == "Takes effect from the next day.")
    }

    @Test func rolloverOptionsAreHalfHoursUpToSixAndOnlyThosePassedAreEnabled() {
        let open = SettingsCopy.rolloverOptions(.upTo(100))
        #expect(open.count == 13 && open.first?.minute == 0 && open.last?.minute == 360)
        #expect(open.filter(\.enabled).map(\.minute) == [0, 30, 60, 90])
        #expect(SettingsCopy.rolloverOptions(.upTo(600)).allSatisfy { $0.enabled })
        #expect(SettingsCopy.rolloverOptions(.after(180)).allSatisfy { !$0.enabled })
    }

    @Test func theMinuteOfDayFollowsTheTimeZone() {
        let instant = Date(timeIntervalSince1970: 1_790_000_000)       // a fixed instant
        let utc = SettingsCopy.minuteOfDay(instant, timeZone: TimeZone(identifier: "UTC")!)
        let tokyo = SettingsCopy.minuteOfDay(instant, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        #expect((tokyo - utc + 1440) % 1440 == 540)
    }

    @Test func everyRefusalHasACalmSentence() {
        let errors: [SettingsError] = [.normalDayOutOfRange, .workingDayInvalid, .rolloverOutOfRange, .rolloverNotChangeableNow,
                                       .emptyName, .nameTooLong, .nameTaken, .tooManyCategories, .notFound]
        for error in errors { #expect(!SettingsCopy.message(for: error).isEmpty) }
        #expect(SettingsCopy.message(for: .tooManyCategories).hasPrefix("Eight is plenty"))
        #expect(SettingsCopy.categoriesSubtitle(active: 4) == "Labels for tasks. 4 of 8 in use.")
    }
}
