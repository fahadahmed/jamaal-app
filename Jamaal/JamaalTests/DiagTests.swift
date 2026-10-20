//
//  DiagTests.swift
//  JamaalTests
//

import Foundation
import Testing
import JamaalCore
@testable import Jamaal

/// The app's diagnostics: an event is recorded, appears in the report with this build's details, and the report holds no content.
struct DiagTests {

    @Test func anEventShowsUpInTheReportAfterTheBuildDetails() {
        Diag.shared.record(.engineTick, .init(.merged, .count(2)), .init(.durationMs, .count(41)))
        let lines = Diag.shared.reportLines()
        #expect(lines.first?.hasPrefix("App: ") == true)
        #expect(lines.contains { $0.hasPrefix("System: ") })
        #expect(lines.contains { $0.hasPrefix("Model: ") })
        #expect(lines.contains { $0.hasSuffix("engine.tick merged=2 durationMs=41") })
    }

    @Test func aFailureIsMarkedAndKeepsOnlyTheErrorsDomainAndCode() {
        let error = NSError(domain: "CKErrorDomain", code: 9, userInfo: [NSLocalizedDescriptionKey: "Pick up the dry cleaning"])
        Diag.shared.record(.syncExport, level: .error, .init(.ok, .flag(false)), .init(.errorCode, .error(error)))
        let text = Diag.shared.reportLines(eventLimit: 200).joined(separator: "\n")
        #expect(text.contains("ERROR sync.export ok=false errorCode=CKErrorDomain 9"))
        #expect(!text.contains("dry cleaning"))
    }

    @Test func theReportLimitsTheEventsItShows() {
        for i in 0..<10 { Diag.shared.record(.widgetsReloaded, .init(.days, .count(i))) }
        let lines = Diag.shared.reportLines(eventLimit: 3)
        #expect(lines.filter { $0.contains("widgets.reloaded") }.count <= 3)
        #expect(lines.contains { $0.hasPrefix("Recent events (last 3 of ") })
    }
}
