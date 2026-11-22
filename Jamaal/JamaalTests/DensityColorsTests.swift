//
//  DensityColorsTests.swift
//  JamaalTests
//

import Testing
import JamaalCore
@testable import Jamaal

/// A habit's days are drawn light, mid, full: the more of a day was done, the fuller its square (Design's habit frame, the token docs).
/// It used to be the other way round, so a completed day was the faintest square (#422).
struct DensityColorsTests {
    @Test func aCompletedDayIsTheFullestStep() {
        #expect(DensityColors.step(for: .complete) == .full)
        #expect(DensityColors.step(for: .partialHigh) == .mid)
        #expect(DensityColors.step(for: .partialLow) == .light)
    }

    @Test func aMissedDayAndAnEmptyOneKeepTheirOwnSteps() {
        #expect(DensityColors.step(for: .missed) == .missed)
        #expect(DensityColors.step(for: .empty) == .empty)
    }

    @Test func theStepsGrowWithHowMuchWasDone() {
        let ramp: [DensityState] = [.partialLow, .partialHigh, .complete]
        let weights = ramp.map { DensityColors.step(for: $0).weight }
        #expect(weights == weights.sorted(), "more done is never a lighter step")
        #expect(Set(weights).count == 3, "and each step is its own")
    }
}
