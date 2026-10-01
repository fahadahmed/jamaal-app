import Foundation
import SwiftData

/// Wizard progress for one planned date. See docs/journeys/night-planning.md.
@Model
public final class NightPlanningSession {
    public var id: UUID = UUID()
    public var forDate: Date = Date.now
    public var currentStep: String = "review"
    public var isComplete: Bool = false
    public var skippedAt: Date? = nil
    public var createdAt: Date = Date.now
    public var completedAt: Date? = nil

    public init() {
    }

    /// Typed view of `currentStep`; reads an unrecognised value as `.unknown` and never writes it back.
    public var step: PlanningStep {
        get { PlanningStep(stored: currentStep) }
        set { if let raw = newValue.storable { currentStep = raw } }
    }
}
