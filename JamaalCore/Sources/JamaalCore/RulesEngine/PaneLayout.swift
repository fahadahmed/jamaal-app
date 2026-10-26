import Foundation

/// When a screen puts a list and a pane side by side. Regular width alone is not enough: held fully open in portrait an iPhone Duo is
/// regular width but 669 pt wide, and two columns would leave neither room. The design draws one column there (docs/journeys/app-flow.md,
/// "iPhone Duo"), so a split needs width as well as the size class (#329).
public enum PaneLayout {

    /// The narrowest width that holds a list (at least 300 pt, see `FoldLayout.listWidthRange`) and a pane worth looking at. An iPad mini
    /// in portrait (744 pt) keeps its two panes; the Duo in portrait (669 pt) does not.
    public static let twoPaneMinimumWidth: CGFloat = 700

    /// `availableWidth` is the screen's width inside the safe area; 0 means it has not been measured yet, when the size class decides alone.
    public static func usesTwoPanes(isRegularWidth: Bool, availableWidth: CGFloat) -> Bool {
        guard isRegularWidth else { return false }
        return availableWidth <= 0 || availableWidth >= twoPaneMinimumWidth
    }
}
