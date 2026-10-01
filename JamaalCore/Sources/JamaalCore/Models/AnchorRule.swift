import Foundation
import SwiftData

/// A recurring rule that generates Anchors. See docs/schema/anchor.md.
@Model
public final class AnchorRule {
    public var id: UUID = UUID()
    public var title: String = ""
    public var sourceKey: String = "custom"
    public var configData: String = "{}"
    public var effortMinutes: Int? = nil
    public var placement: String = "fixed"
    public var isEnabled: Bool = true
    public var isArchived: Bool = false
    public var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Anchor.rule) public var anchors: [Anchor]?

    public init(title: String = "") {
        self.title = title
    }

    /// Typed view of `sourceKey`; reads an unrecognised value as `.unknown` and never writes it back.
    public var source: AnchorSource {
        get { AnchorSource(stored: sourceKey) }
        set { if let raw = newValue.storable { sourceKey = raw } }
    }

    /// Typed view of `placement`; reads an unrecognised value as `.unknown` and never writes it back.
    public var placementKind: AnchorPlacement {
        get { AnchorPlacement(stored: placement) }
        set { if let raw = newValue.storable { placement = raw } }
    }
}
