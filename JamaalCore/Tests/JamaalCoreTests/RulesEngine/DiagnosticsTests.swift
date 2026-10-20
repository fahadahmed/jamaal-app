import Foundation
import Testing
@testable import JamaalCore

/// The on-device event log (docs/architecture/observability.md): events carry names, ids, counts and codes, never content, and a
/// fixed number of the most recent ones are kept.
struct DiagnosticsTests {

    private let utc = TimeZone(identifier: "UTC")!
    private func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_790_000_000 + seconds) }
    private func event(_ name: DiagnosticName = .engineTick, at seconds: TimeInterval = 0, level: DiagnosticLevel = .info,
                       _ fields: [DiagnosticEvent.Field] = []) -> DiagnosticEvent {
        DiagnosticEvent(at: at(seconds), name: name, level: level, fields: fields)
    }

    // MARK: Events

    @Test func anEventKnowsItsCategoryFromItsName() {
        #expect(DiagnosticName.syncImport.category == .sync)
        #expect(DiagnosticName.engineTick.category == .engine)
        #expect(DiagnosticName.focusFinished.category == .focus)
        #expect(DiagnosticName.storeOpenFailed.category == .store)
        #expect(Set(DiagnosticName.allCases.map(\.category)).isSubset(of: Set(DiagnosticCategory.allCases)))
    }

    @Test func aLineReadsAsATimeANameAndItsFields() {
        let e = event(.engineTick, at: 0, [.init(.seeded, .flag(false)), .init(.merged, .count(2)), .init(.durationMs, .count(41))])
        #expect(e.line(timeZone: utc) == "2026-09-21 14:13:20 engine.tick seeded=false merged=2 durationMs=41")
    }

    @Test func anErrorLevelIsMarked() {
        #expect(event(.syncExport, level: .error).line(timeZone: utc).contains(" ERROR sync.export"))
        #expect(!event(.syncExport, level: .info).line(timeZone: utc).contains("INFO"))
    }

    // MARK: Values cannot carry content

    @Test func anIdIsTheFirstFourCharactersOfAUUID() {
        let id = UUID(uuidString: "3F9A1C2E-0000-4000-8000-000000000001")!
        #expect(DiagnosticValue.id(id).text == "3F9A")
    }

    @Test func anErrorBecomesItsDomainAndCodeAndNothingElse() {
        let error = NSError(domain: "CKErrorDomain", code: 9, userInfo: [NSLocalizedDescriptionKey: "Draft the architecture review"])
        let value = DiagnosticValue.error(error)
        #expect(value.text == "CKErrorDomain 9")
        #expect(!value.text.contains("Draft"), "the message may hold anything; only the domain and code are kept")
    }

    @Test func aFlagAndACountAreTheirPlainValues() {
        #expect(DiagnosticValue.flag(true).text == "true")
        #expect(DiagnosticValue.count(-3).text == "-3")
    }

    /// Names and keys are fixed lists, so a line can only hold words we wrote. This keeps them to plain tokens.
    @Test func everyNameAndKeyIsAPlainToken() {
        let token = /^[A-Za-z]+(\.[A-Za-z]+)*$/
        for name in DiagnosticName.allCases { #expect(name.rawValue.wholeMatch(of: token) != nil, "\(name.rawValue)") }
        for key in DiagnosticKey.allCases { #expect(key.rawValue.wholeMatch(of: token) != nil, "\(key.rawValue)") }
    }

    // MARK: The ring buffer

    @Test func theLogKeepsTheMostRecentEventsInOrder() {
        var log = DiagnosticLog(capacity: 3)
        for i in 0..<5 { log.append(event(at: Double(i), [.init(.merged, .count(i))])) }
        #expect(log.events.count == 3)
        #expect(log.events.map { $0.fields.first?.value.text } == ["2", "3", "4"])
    }

    @Test func recentReturnsTheLastFewOldestFirst() {
        var log = DiagnosticLog(capacity: 10)
        for i in 0..<6 { log.append(event(at: Double(i), [.init(.merged, .count(i))])) }
        #expect(log.recent(2).map { $0.fields.first?.value.text } == ["4", "5"])
        #expect(log.recent(0).isEmpty)
        #expect(log.recent(99).count == 6)
    }

    @Test func aZeroCapacityLogKeepsNothingAndDoesNotCrash() {
        var log = DiagnosticLog(capacity: 0)
        log.append(event())
        #expect(log.events.isEmpty)
    }

    @Test func theLogSurvivesBeingSavedAndLoaded() throws {
        var log = DiagnosticLog(capacity: 5)
        log.append(event(.syncImport, level: .error, [.init(.errorCode, .error(NSError(domain: "D", code: 1)))]))
        let back = try JSONDecoder().decode(DiagnosticLog.self, from: JSONEncoder().encode(log))
        #expect(back == log)
    }

    @Test func aLogFromAnOlderOrNewerAppWithAnUnknownNameIsSkippedNotFatal() throws {
        let json = """
        {"capacity":5,"events":[{"at":0,"name":"app.launched","level":"info","fields":[]},{"at":1,"name":"future.thing","level":"info","fields":[]}]}
        """
        let log = try JSONDecoder().decode(DiagnosticLog.self, from: Data(json.utf8))
        #expect(log.events.map(\.name) == [.appLaunched])
    }

    // MARK: The report

    @Test func theEnvironmentLinesSayWhatBuildThisIs() {
        let env = DiagnosticEnvironment(appVersion: "1.0", build: "7", os: "iOS 27.0", device: "iPad14,5", channel: .testFlight)
        #expect(DiagnosticsCopy.environmentLines(env) == [
            "App: 1.0 (7), TestFlight", "System: iOS 27.0", "Model: iPad14,5",
        ])
    }

    @Test func theEventLinesAreTheLastFewAndSaySoWhenThereAreNone() {
        var log = DiagnosticLog(capacity: 10)
        #expect(DiagnosticsCopy.eventLines(log, limit: 50, timeZone: utc) == ["Recent events: none yet"])
        for i in 0..<4 { log.append(event(at: Double(i), [.init(.merged, .count(i))])) }
        let lines = DiagnosticsCopy.eventLines(log, limit: 2, timeZone: utc)
        #expect(lines.count == 3)
        #expect(lines[0] == "Recent events (last 2 of 4):")
        #expect(lines[1].hasSuffix("merged=2") && lines[2].hasSuffix("merged=3"))
    }
}
