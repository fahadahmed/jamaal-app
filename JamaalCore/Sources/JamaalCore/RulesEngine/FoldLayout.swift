import Foundation

// Where the two panes of Today meet on a foldable iPhone (the iPhone Duo, iOS 27.1). The system reports the crease as a *division*
// reserved region of the window: a frame (with margins for interactive content on each side) and whether it is active. Open flat it is
// inactive; held half open it is active, running the whole height down the middle. The app reads the regions; what to make of them is
// decided here, so it can be tested without a device (docs/journeys/app-flow.md, "iPhone Duo").

public enum FoldLayout {

    /// One reserved region, in the window's coordinates.
    public struct Region: Equatable, Sendable {
        public var minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat
        public var isActive: Bool

        public init(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat, isActive: Bool) {
            self.minX = minX; self.maxX = maxX; self.minY = minY; self.maxY = maxY; self.isActive = isActive
        }
    }

    /// A list needs room for its rows and a pane beside it needs room for a task; outside this range the list keeps its own width.
    public static let listWidthRange: ClosedRange<CGFloat> = 300...640

    /// The x position of a vertical crease: the middle of the first **active** division region that runs (almost) the whole height, is
    /// narrow, and is not at an edge. A region across the screen, a short one or an inactive one is not a crease for a side-by-side layout.
    public static func crease(in regions: [Region], viewSize: CGSize) -> CGFloat? {
        for region in regions where region.isActive {
            let width = region.maxX - region.minX
            let height = region.maxY - region.minY
            let middle = (region.minX + region.maxX) / 2
            guard height >= viewSize.height * 0.9,
                  width <= viewSize.width * 0.25,
                  (viewSize.width * 0.2...viewSize.width * 0.8).contains(middle) else { continue }
            return middle
        }
        return nil
    }

    /// How wide the list column is: it runs from where it starts to the crease, so the list fills its half of the display and the
    /// details pane starts at the crease. With no crease, or a width outside `listWidthRange`, it keeps `fallback`.
    public static func listWidth(creaseX: CGFloat?, listOriginX: CGFloat, fallback: CGFloat) -> CGFloat {
        guard let creaseX else { return fallback }
        let width = creaseX - listOriginX
        return listWidthRange.contains(width) ? width : fallback
    }
}
