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

    // MARK: A crease across the display (tabletop), #329

    /// What the simulator reported turned to portrait, half open like a laptop: a 669 x 951 pt window with an active region at y 455-495.
    private let portrait = CGSize(width: 669, height: 951)
    private func across(_ minY: CGFloat, _ maxY: CGFloat, x: ClosedRange<CGFloat> = 0...669, active: Bool = true) -> FoldLayout.Region {
        .init(minX: x.lowerBound, maxX: x.upperBound, minY: minY, maxY: maxY, isActive: active)
    }

    @Test func anActiveRegionRunningTheWholeWidthIsAHorizontalCreaseInItsMiddle() {
        #expect(FoldLayout.horizontalCrease(in: [across(455, 495)], viewSize: portrait) == 475)
    }

    @Test func aVerticalRegionIsNotAHorizontalCreaseAndTheOtherWayRound() {
        #expect(FoldLayout.horizontalCrease(in: [region(455, 495)], viewSize: view) == nil)
        #expect(FoldLayout.crease(in: [across(455, 495)], viewSize: portrait) == nil)
    }

    @Test func anInactiveOrShortOrEdgeHorizontalRegionIsIgnored() {
        #expect(FoldLayout.horizontalCrease(in: [across(455, 495, active: false)], viewSize: portrait) == nil)
        #expect(FoldLayout.horizontalCrease(in: [across(455, 495, x: 0...200)], viewSize: portrait) == nil)
        #expect(FoldLayout.horizontalCrease(in: [across(20, 60)], viewSize: portrait) == nil)
        #expect(FoldLayout.horizontalCrease(in: [across(900, 940)], viewSize: portrait) == nil)
    }

    @Test func theTopPaneRunsFromWhereTheScreenStartsToTheCrease() {
        #expect(FoldLayout.topPaneHeight(creaseY: 475, originY: 0, availableHeight: 951) == 475)
        #expect(FoldLayout.topPaneHeight(creaseY: 475, originY: 24, availableHeight: 927) == 451)
    }

    @Test func aTopPaneThatWouldBeTooSmallOrTooLargeIsNotUsed() {
        #expect(FoldLayout.topPaneHeight(creaseY: 100, originY: 0, availableHeight: 951) == nil)
        #expect(FoldLayout.topPaneHeight(creaseY: 900, originY: 0, availableHeight: 951) == nil)
        #expect(FoldLayout.topPaneHeight(creaseY: nil, originY: 0, availableHeight: 951) == nil)
    }
}

