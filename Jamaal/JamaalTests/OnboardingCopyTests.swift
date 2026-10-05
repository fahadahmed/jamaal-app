//
//  OnboardingCopyTests.swift
//  JamaalTests
//

import Testing
import JamaalCore
@testable import Jamaal

struct OnboardingCopyTests {

    @Test func theReadyLineCountsWhatWasActuallyMade() {
        #expect(OnboardingCopy.readyBody(tasks: 1, habits: 1, anchors: 0) == "Until then, today has one task and one habit.")
        #expect(OnboardingCopy.readyBody(tasks: 1, habits: 1, anchors: 1) == "Until then, today has one task, one habit and one Anchor.")
        #expect(OnboardingCopy.readyBody(tasks: 2, habits: 0, anchors: 3) == "Until then, today has 2 tasks and 3 Anchors.")
        #expect(OnboardingCopy.readyBody(tasks: 0, habits: 0, anchors: 0) == "Until then, today is yours.")
        #expect(OnboardingCopy.readyBody(tasks: 0, habits: 1, anchors: 0) == "Until then, today has one habit.")
    }

    @Test func theDayZeroCardNamesThePlanningTime() {
        #expect(OnboardingCopy.tonightTitle == "Tonight, we'll plan tomorrow.")
        #expect(OnboardingCopy.tonightLine(planningMinute: 20 * 60) == "At 20:00 I'll ask how today went, and we'll set up tomorrow together.")
        #expect(OnboardingCopy.tonightLine(planningMinute: 19 * 60 + 30).contains("19:30"))
    }

    @Test func theHabitButtonNamesTheChoice() {
        #expect(OnboardingCopy.addHabitButton("Qur'an reading") == "Add Qur'an reading")
        #expect(OnboardingCopy.addHabitButton("Water") == "Add Water")
    }

    @Test func eachRefusalIsSaidCalmly() {
        #expect(OnboardingCopy.message(for: TaskCreationError.emptyTitle) == "Give it a name first.")
        #expect(OnboardingCopy.message(for: HabitEditError.emptyTitle) == "Give it a name first.")
        #expect(OnboardingCopy.message(for: SettingsError.workingDayInvalid).hasPrefix("The working day needs"))
        struct Odd: Error {}
        #expect(OnboardingCopy.message(for: Odd()) == "That couldn't be saved. Try again.")
    }

    @Test func theCopyPromisesNothingTheAppDoesNot() {
        // The app suggests a better normal day from real use; it never learns silently, and there are no streaks or guilt.
        #expect(OnboardingCopy.daySubtitle.contains("I can suggest"))
        #expect(!OnboardingCopy.daySubtitle.lowercased().contains("learn"))
        #expect(OnboardingCopy.notHere == "Projects and boards · Streaks and guilt")
        #expect(OnboardingCopy.ideaRows.count == 3)
    }
}
