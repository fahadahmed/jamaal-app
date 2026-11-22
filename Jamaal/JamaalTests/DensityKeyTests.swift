//
//  DensityKeyTests.swift
//  JamaalTests
//

import Testing
import JamaalCore
@testable import Jamaal

/// The key under a habit heatmap says what each colour means (#424).
struct DensityKeyTests {
    @Test func aYesNoHabitHasNoPartialSteps() {
        let items = DensityKeyCopy.items(for: .yesNo(.binary))
        #expect(items.map(\.word) == ["Done", "Not done", "Nothing due"])
        #expect(items.map(\.step) == [.full, .missed, .empty])
    }

    @Test func anAvoidHabitSaysHeldAndSlipped() {
        #expect(DensityKeyCopy.items(for: .yesNo(.avoid)).map(\.word) == ["Held", "Slipped", "Nothing due"])
    }

    @Test func aCountedOrTimedHabitShowsTheThreeShadesFromLightToFull() {
        let items = DensityKeyCopy.items(for: .amount)
        #expect(items.map(\.word) == ["Under half", "Half or more", "Target reached", "Not done", "Nothing due"])
        #expect(items.map(\.step) == [.light, .mid, .full, .missed, .empty])
    }

    @Test func aGroupKeyIsAboutHowManyOfItsHabitsWereDone() {
        let items = DensityKeyCopy.items(for: .group)
        #expect(items.map(\.word) == ["Every habit", "Half or more", "Under half", "None", "Nothing due"])
        #expect(items.map(\.step) == [.full, .mid, .light, .missed, .empty])
    }

    @Test func theKindPicksTheStyle() {
        #expect(DensityKeyCopy.style(for: .binary) == .yesNo(.binary))
        #expect(DensityKeyCopy.style(for: .avoid) == .yesNo(.avoid))
        #expect(DensityKeyCopy.style(for: .counted) == .amount)
        #expect(DensityKeyCopy.style(for: .timed) == .amount)
        #expect(DensityKeyCopy.style(for: .unknown) == .yesNo(.binary))
    }

    @Test func noWordIsAnAlarmOrAScore() {
        let all = [DensityKeyCopy.Style.yesNo(.binary), .yesNo(.avoid), .amount, .group].flatMap { DensityKeyCopy.items(for: $0).map(\.word) }
        for word in all { #expect(!word.contains("!") && !word.lowercased().contains("fail") && !word.lowercased().contains("streak")) }
    }
}
