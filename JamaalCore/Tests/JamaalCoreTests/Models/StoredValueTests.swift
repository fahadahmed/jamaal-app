import Foundation
import Testing
@testable import JamaalCore

/// docs/schema/overview.md, "Raw values": an unrecognised raw string reads as `.unknown`,
/// and `.unknown` is never written back, so a newer app's row is kept untouched.
struct StoredValueTests {

    @Test func knownValuesRoundTrip() {
        for importance in Importance.allCases where importance != .unknown {
            #expect(Importance(stored: importance.rawValue) == importance)
        }
    }

    @Test(arguments: ["", "urgent", "LOW", "low "])
    func unrecognisedValuesReadAsUnknown(raw: String) {
        #expect(Importance(stored: raw) == .unknown)
        #expect(Importance(stored: raw).isUnknown)
    }

    @Test func unknownIsNotStorable() {
        #expect(Importance.unknown.storable == nil)
        #expect(Importance.high.storable == "high")
    }

    @Test func repeatKindOffUsesTheDocumentedRawValue() {
        #expect(RepeatKind.off.rawValue == "none")
        #expect(RepeatKind(stored: "none") == .off)
    }

    /// The raw strings are persisted in CloudKit, which is append-only in production: this
    /// pins every documented value so a rename can't slip through.
    @Test func documentedRawValuesAreStable() {
        #expect(values(Importance.self) == ["low", "medium", "high"])
        #expect(values(RepeatKind.self) == ["none", "daily", "weekly", "monthly"])
        #expect(values(DeferralReason.self) == ["tooMuch", "notReady", "noLonger", "reschedule", "unspecified"])
        #expect(values(SessionOutcome.self) == ["running", "finished", "deferred", "dropped", "abandoned", "autoClosed", "manual"])
        #expect(values(CategoryPreset.self) == ["personal", "family", "work"])
        #expect(values(CategoryColor.self) == ["accent", "blue", "ochre", "plum", "slate"])
        #expect(values(HabitKind.self) == ["binary", "counted", "timed", "avoid"])
        #expect(values(HabitFrequency.self) == ["daily", "weekdays", "custom"])
        #expect(values(HabitPreset.self) == ["quran", "dhikr", "exercise", "running"])
        #expect(values(AttendanceStatus.self) == ["pending", "attended", "missed", "skipped", "delegated"])
        #expect(values(AnchorSource.self) == ["prayerWindow", "schoolRun", "binNight", "plantWatering", "custom"])
        #expect(values(AnchorPlacement.self) == ["fixed", "flexible"])
        #expect(values(CapacityLevel.self) == ["low", "medium", "high"])
        #expect(values(PlanningStep.self) == ["review", "carry", "build", "load", "close"])
        #expect(values(NudgeKind.self) == ["wellbeing", "guidance", "fatigue", "windowClosing", "overload", "morningPlanCard", "habitPromotion", "normalDaySuggestion"])
        #expect(values(PauseReason.self) == ["travel", "illness", "cycle", "other"])
    }

    private func values<T: StoredValue>(_: T.Type) -> [String] {
        T.allCases.filter { !$0.isUnknown }.map(\.rawValue)
    }
}
