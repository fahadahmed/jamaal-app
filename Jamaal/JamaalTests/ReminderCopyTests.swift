//
//  ReminderCopyTests.swift
//  JamaalTests
//

import Testing
import JamaalCore
@testable import Jamaal

struct ReminderCopyTests {

    @Test func theHomeRowSaysWhereRemindersStand() {
        #expect(ReminderCopy.homeValue(switchOn: false, permission: .granted, device: "iPhone") == "Off on this iPhone")
        #expect(ReminderCopy.homeValue(switchOn: false, permission: .denied, device: "iPad") == "Off on this iPad")
        #expect(ReminderCopy.homeValue(switchOn: true, permission: .granted, device: "iPhone") == "On")
        #expect(ReminderCopy.homeValue(switchOn: true, permission: .notAsked, device: "iPhone") == "Not turned on yet")
        #expect(ReminderCopy.homeValue(switchOn: true, permission: .denied, device: "iPhone") == "Off in Settings")
    }

    @Test func theWarningCardNamesTheDeviceAndTheRightButton() {
        #expect(ReminderCopy.warningTitle(permission: .denied, device: "iPhone") == "Notifications are off for Jamaal on this iPhone, so these won't arrive:")
        #expect(ReminderCopy.warningTitle(permission: .notAsked, device: "iPad").contains("hasn't been allowed"))
        #expect(ReminderCopy.warningButton(.notAsked, device: "iPhone") == "Turn on reminders")
        #expect(ReminderCopy.warningButton(.denied, device: "iPhone") == "Open iPhone Settings")
        #expect(ReminderCopy.habitRow(blocked: true) == "Set per habit · notifications are off")
        #expect(ReminderCopy.habitRow(blocked: false) == "Set on each habit's form")
    }
}
