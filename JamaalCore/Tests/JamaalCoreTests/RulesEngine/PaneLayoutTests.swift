import Foundation
import Testing
@testable import JamaalCore

/// When a screen splits into a list and a pane beside it (#329). Regular width alone is not enough: an iPhone Duo held fully open in
/// portrait is regular width but only 669 pt wide, where two columns leave neither of them room, and the design draws one column there
/// (mockups/screens/6-ipad-duo-macos/Duo-inner-portrait.png).
struct PaneLayoutTests {

    @Test func aWideRegularDisplayUsesTwoPanes() {
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 867))      // the Duo's inner display, landscape
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 1194))     // an iPad
    }

    @Test func aNarrowRegularDisplayUsesOneColumn() {
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 669) == false)   // the Duo's inner display, portrait
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 520) == false)   // a narrow Split View window
    }

    @Test func anIPadInPortraitStillUsesTwoPanes() {
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 744))      // an iPad mini, the narrowest iPad
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 820))
    }

    @Test func compactWidthNeverDoes() {
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: false, availableWidth: 1000) == false)
    }

    @Test func beforeTheWidthIsMeasuredRegularMeansTwoPanes() {
        // As before the width rule: the first frame is not a one-column flash on an iPad.
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 0))
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: false, availableWidth: 0) == false)
    }

    @Test func theThresholdIsExactlySevenHundred() {
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 700))
        #expect(PaneLayout.usesTwoPanes(isRegularWidth: true, availableWidth: 699.5) == false)
    }
}
