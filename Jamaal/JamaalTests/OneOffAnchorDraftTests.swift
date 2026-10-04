//
//  OneOffAnchorDraftTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The one-off Anchor on the Add sheet (AN-08): its starting window and what the button says.
struct OneOffAnchorDraftTests {
    private let today = CalendarDate(year: 2026, month: 10, day: 15)!                 // a Thursday

    @Test func theWindowStartsAtTheNextWholeHourAndLastsAnHour() {
        let d = OneOffAnchorDraft(today: today, nowMinute: 9 * 60 + 20)
        #expect(d.day == today)
        #expect(d.startMinute == 10 * 60 && d.endMinute == 11 * 60)
    }

    @Test func lateInTheEveningItStaysWithinTheDay() {
        let d = OneOffAnchorDraft(today: today, nowMinute: 23 * 60 + 10)
        #expect(d.startMinute == 22 * 60 && d.endMinute == 23 * 60)
        #expect(d.endMinute <= 1439)
    }

    @Test func movingTheStartPastTheEndPushesTheEndAnHourOn() {
        var d = OneOffAnchorDraft(today: today, nowMinute: 9 * 60)
        d.setStart(14 * 60)
        #expect(d.startMinute == 14 * 60 && d.endMinute == 15 * 60)
        d.setStart(8 * 60)
        #expect(d.endMinute == 15 * 60)                                                // an earlier start leaves the end alone
    }

    @Test func settingTheEndBeforeTheStartIsRefusedByKeepingAtLeastFifteenMinutes() {
        var d = OneOffAnchorDraft(today: today, nowMinute: 9 * 60)
        d.setEnd(9 * 60)
        #expect(d.endMinute == d.startMinute + 15)
    }

    @Test func theButtonSaysWhenItIs() {
        var d = OneOffAnchorDraft(today: today, nowMinute: 9 * 60)
        #expect(d.buttonTitle == "Add for today")
        d.day = today.addingDays(1); #expect(d.buttonTitle == "Add for tomorrow")
        d.day = today.addingDays(3); #expect(d.buttonTitle == "Add for Sunday")
        d.day = today.addingDays(20); #expect(d.buttonTitle == "Add for 4 Nov")
    }

    @Test func aTitleMakesItReady() {
        var d = OneOffAnchorDraft(today: today, nowMinute: 9 * 60)
        #expect(!d.canSave)
        d.title = "  "
        #expect(!d.canSave)
        d.title = "Dentist"
        #expect(d.canSave)
    }
}
