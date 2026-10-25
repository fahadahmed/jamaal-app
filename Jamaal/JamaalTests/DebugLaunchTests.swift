//
//  DebugLaunchTests.swift
//  JamaalTests
//

import Testing
@testable import Jamaal

/// The launch argument that lets a UI test pin the working day's start so Night Planning behaves the same at every hour (#296).
struct DebugLaunchTests {

    @Test func theDayStartIsReadFromItsArgument() {
        #expect(DebugLaunch.dayStartMinute(in: ["-JamaalInMemory", "-JamaalDayStartMinute", "0"]) == 0)
        #expect(DebugLaunch.dayStartMinute(in: ["-JamaalDayStartMinute", "480"]) == 480)
    }

    @Test func itIsKeptWithinTheDay() {
        #expect(DebugLaunch.dayStartMinute(in: ["-JamaalDayStartMinute", "-30"]) == 0)
        #expect(DebugLaunch.dayStartMinute(in: ["-JamaalDayStartMinute", "5000"]) == 1439)
    }

    @Test func noArgumentOrANonNumberLeavesTheSettingAlone() {
        #expect(DebugLaunch.dayStartMinute(in: ["-JamaalInMemory"]) == nil)
        #expect(DebugLaunch.dayStartMinute(in: ["-JamaalDayStartMinute"]) == nil)
        #expect(DebugLaunch.dayStartMinute(in: ["-JamaalDayStartMinute", "soon"]) == nil)
    }
}
