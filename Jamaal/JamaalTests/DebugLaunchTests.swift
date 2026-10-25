//
//  DebugLaunchTests.swift
//  JamaalTests
//

import JamaalCore
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

    // MARK: The weekday level (#324): Saturday and Sunday start on Low, which hides a task that isn't urgent and important.

    @Test func theWeekdayLevelIsReadFromItsArgument() {
        #expect(DebugLaunch.weekdayLevel(in: ["-JamaalWeekdayLevel", "medium"]) == .medium)
        #expect(DebugLaunch.weekdayLevel(in: ["-JamaalInMemory", "-JamaalWeekdayLevel", "high"]) == .high)
        #expect(DebugLaunch.weekdayLevel(in: ["-JamaalWeekdayLevel", "low"]) == .low)
    }

    @Test func noArgumentOrAnUnknownLevelLeavesTheDefaultsAlone() {
        #expect(DebugLaunch.weekdayLevel(in: ["-JamaalInMemory"]) == nil)
        #expect(DebugLaunch.weekdayLevel(in: ["-JamaalWeekdayLevel"]) == nil)
        #expect(DebugLaunch.weekdayLevel(in: ["-JamaalWeekdayLevel", "tuesday"]) == nil)
    }
}
