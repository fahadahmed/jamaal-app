import Foundation
import Testing
@testable import JamaalCore

/// Where the two panes of Today meet on an iPhone Duo (#329). The system reports the crease as a *division* region; the numbers below
/// are what the simulator reported for the inner display held half open: a 951 × 669 pt window with an active region at x 455–495
/// (20 pt of margin each side) running the whole height, so the crease is at x 475.
struct FoldLayoutTests {

    private let view = CGSize(width: 951, height: 669)
    private func region(_ minX: CGFloat, _ maxX: CGFloat, y: ClosedRange<CGFloat> = 0...669, active: Bool = true) -> FoldLayout.Region {
        .init(minX: minX, maxX: maxX, minY: y.lowerBound, maxY: y.upperBound, isActive: active)
    }

    // MARK: Finding the crease

    @Test func anActiveRegionRunningTheWholeHeightIsACreaseInItsMiddle() {
        #expect(FoldLayout.crease(in: [region(455, 495)], viewSize: view) == 475)
    }

    @Test func noRegionsMeansNoCrease() {
        #expect(FoldLayout.crease(in: [], viewSize: view) == nil)
    }

    @Test func anInactiveRegionIsNotACrease() {
        // Fully open and flat: the system still lists the region, but it is not active.
        #expect(FoldLayout.crease(in: [region(455, 495, active: false)], viewSize: view) == nil)
    }

    @Test func aRegionThatDoesNotRunTheWholeHeightIsNotACrease() {
        #expect(FoldLayout.crease(in: [region(455, 495, y: 0...200)], viewSize: view) == nil)
    }

    @Test func aHorizontalCreaseIsNotUsedForTheSideBySideLayout() {
        // A fold across the screen (the device turned) would split top from bottom, not list from details.
        let across = FoldLayout.Region(minX: 0, maxX: 951, minY: 320, maxY: 360, isActive: true)
        #expect(FoldLayout.crease(in: [across], viewSize: view) == nil)
    }

    @Test func aCreaseTooNearAnEdgeIsIgnored() {
        #expect(FoldLayout.crease(in: [region(20, 60)], viewSize: view) == nil)
        #expect(FoldLayout.crease(in: [region(900, 940)], viewSize: view) == nil)
    }

    @Test func theFirstSuitableRegionWinsWhenThereAreSeveral() {
        #expect(FoldLayout.crease(in: [region(10, 20, y: 0...50), region(455, 495)], viewSize: view) == 475)
    }

    // MARK: The list's width

    @Test func theListRunsToTheCreaseFromWhereItStarts() {
        #expect(FoldLayout.listWidth(creaseX: 475, listOriginX: 0, fallback: 440) == 475)
        #expect(FoldLayout.listWidth(creaseX: 475, listOriginX: 20, fallback: 440) == 455)    // a leading inset moves where it starts
    }

    @Test func withNoCreaseTheListKeepsItsOwnWidth() {
        #expect(FoldLayout.listWidth(creaseX: nil, listOriginX: 0, fallback: 440) == 440)
    }

    @Test func aListThatWouldBeTooNarrowOrTooWideKeepsItsOwnWidth() {
        #expect(FoldLayout.listWidth(creaseX: 200, listOriginX: 0, fallback: 440) == 440)     // under the 300 pt a list needs
        #expect(FoldLayout.listWidth(creaseX: 900, listOriginX: 0, fallback: 440) == 440)     // over the 640 pt a list may take
    }
}
