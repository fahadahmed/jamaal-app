import Foundation
import Testing
@testable import JamaalCore

/// What MetricKit reports (a crash, a hang, a CPU or disk-write exception) becomes one on-device event, with numbers only: no call
/// stack, no termination text, nothing a person typed (docs/architecture/observability.md).
struct SystemDiagnosticTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let when = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func aCrashIsAnErrorWithItsExceptionSignalAndBuild() {
        let report = SystemDiagnostic(kind: .crash, at: when, exceptionType: 1, exceptionCode: 50, signal: 11, build: 7)
        let event = report.event
        #expect(event.name == .systemCrash)
        #expect(event.level == .error)
        #expect(event.line(timeZone: utc) == "2026-09-21 14:13:20 ERROR system.crash exceptionType=1 exceptionCode=50 signal=11 build=7")
    }

    @Test func aHangIsANoticeWithItsLengthInMilliseconds() {
        let report = SystemDiagnostic(kind: .hang, at: when, durationMs: 4_250, build: 7)
        #expect(report.event.level == .notice)
        #expect(report.event.line(timeZone: utc) == "2026-09-21 14:13:20 NOTICE system.hang durationMs=4250 build=7")
    }

    @Test func aCPUOrDiskWriteExceptionIsANotice() {
        #expect(SystemDiagnostic(kind: .cpuException, at: when).event.name == .systemCPUException)
        #expect(SystemDiagnostic(kind: .diskWriteException, at: when).event.name == .systemDiskWrite)
        #expect(SystemDiagnostic(kind: .cpuException, at: when).event.level == .notice)
        #expect(SystemDiagnostic(kind: .diskWriteException, at: when).event.level == .notice)
    }

    @Test func aValueThatIsMissingLeavesItsFieldOut() {
        let event = SystemDiagnostic(kind: .crash, at: when, signal: 6).event
        #expect(event.fields.map(\.key) == [.signal])
        #expect(SystemDiagnostic(kind: .hang, at: when).event.fields.isEmpty)
    }

    @Test func theBuildIsKeptOnlyWhenItIsAWholeNumber() {
        #expect(SystemDiagnostic.build(from: "7") == 7)
        #expect(SystemDiagnostic.build(from: "142") == 142)
        #expect(SystemDiagnostic.build(from: "1.0.7") == nil)
        #expect(SystemDiagnostic.build(from: "beta") == nil)
        #expect(SystemDiagnostic.build(from: "") == nil)
        #expect(SystemDiagnostic.build(from: nil) == nil)
    }

    @Test func aNegativeOrAbsurdLengthIsNotKept() {
        #expect(SystemDiagnostic(kind: .hang, at: when, durationMs: -5).event.fields.isEmpty)
    }

    @Test func theNewNamesBelongToTheSystemCategoryAndStayInTheFixedFormat() {
        let names: [DiagnosticName] = [.systemCrash, .systemHang, .systemCPUException, .systemDiskWrite]
        for name in names { #expect(name.category == .system) }
        #expect(DiagnosticName.systemCPUException.rawValue == "system.cpuException")
        #expect(DiagnosticName.systemDiskWrite.rawValue == "system.diskWrite")
    }

    @Test func anEventSurvivesBeingSavedAndLoadedInTheLog() throws {
        var log = DiagnosticLog(capacity: 5)
        log.append(SystemDiagnostic(kind: .crash, at: when, exceptionType: 1, signal: 11, build: 7).event)
        let loaded = try JSONDecoder().decode(DiagnosticLog.self, from: try JSONEncoder().encode(log))
        #expect(loaded == log)
        #expect(loaded.events.first?.name == .systemCrash)
    }

    // MARK: Slice 4: the app was running when it was last closed

    private let launchTime = Date(timeIntervalSince1970: 1_790_100_000)

    @Test func aFirstLaunchHasNothingBeforeIt() {
        let result = RunTracker.launch(previous: nil, build: "7", now: launchTime)
        #expect(result.endedUnexpectedly == false)
        #expect(result.record.wasActive)
        #expect(result.record.build == "7")
    }

    @Test func aRunThatWentToTheBackgroundEndedCleanly() {
        let before = RunTracker.leftTheScreen(RunRecord(wasActive: true, build: "7", since: launchTime))
        #expect(before.wasActive == false)
        let result = RunTracker.launch(previous: before, build: "7", now: launchTime)
        #expect(result.endedUnexpectedly == false)
    }

    @Test func aRunThatWasStillActiveEndedUnexpectedly() {
        let before = RunRecord(wasActive: true, build: "7", since: launchTime.addingTimeInterval(-600))
        let result = RunTracker.launch(previous: before, build: "7", now: launchTime)
        #expect(result.endedUnexpectedly)
        #expect(result.previousBuild == "7")
        #expect(result.record.wasActive)
        #expect(result.record.since == launchTime)
    }

    @Test func anUpdateIsNotAnUnexpectedEnd() {
        // Installing a new build closes the old one while it is open.
        let before = RunRecord(wasActive: true, build: "6", since: launchTime.addingTimeInterval(-600))
        #expect(RunTracker.launch(previous: before, build: "7", now: launchTime).endedUnexpectedly == false)
    }

    @Test func becomingActiveAgainMarksTheRunActive() {
        let away = RunTracker.leftTheScreen(RunRecord(wasActive: true, build: "7", since: launchTime))
        let back = RunTracker.becameActive(away, now: launchTime.addingTimeInterval(60))
        #expect(back.wasActive)
        #expect(back.since == launchTime.addingTimeInterval(60))
    }

    @Test func anUnexpectedEndIsALoggedNoticeWithTheBuild() {
        let event = RunTracker.unexpectedExitEvent(previousBuild: "7", at: launchTime)
        #expect(event.name == .appUnexpectedExit)
        #expect(event.level == .notice)
        #expect(event.line(timeZone: utc) == "2026-09-22 18:00:00 NOTICE app.unexpectedExit build=7")
        #expect(RunTracker.unexpectedExitEvent(previousBuild: "beta", at: launchTime).fields.isEmpty)
    }

    @Test func theNoticeIsShownOnceAndGoesAwayWhenAnswered() {
        var notice = ExitNotice()
        #expect(notice.isShown(now: launchTime) == false)
        notice.detected(at: launchTime)
        #expect(notice.isShown(now: launchTime.addingTimeInterval(3_600)))
        notice.answered()
        #expect(notice.isShown(now: launchTime.addingTimeInterval(3_600)) == false)
    }

    @Test func aNoticeNobodyAnsweredFadesAfterThreeDays() {
        var notice = ExitNotice()
        notice.detected(at: launchTime)
        #expect(notice.isShown(now: launchTime.addingTimeInterval(2 * 86_400 + 3_600)))
        #expect(notice.isShown(now: launchTime.addingTimeInterval(3 * 86_400 + 1)) == false)
    }

    @Test func aNoticeIsNeverShownBeforeItWasDetected() {
        var notice = ExitNotice()
        notice.detected(at: launchTime)
        #expect(notice.isShown(now: launchTime.addingTimeInterval(-10)) == false)
    }

    // MARK: Slice 5: the daily summary

    @Test func aQuietDayIsAnInfoLineWithTheExitCounts() {
        let day = DailyHealth(at: launchTime, normalExits: 5, abnormalExits: 0, memoryExits: 0, watchdogExits: 0)
        #expect(day.event.name == .systemDaily)
        #expect(day.event.level == .info)
        #expect(day.event.line(timeZone: utc) == "2026-09-22 18:00:00 system.daily exitsNormal=5 exitsAbnormal=0 exitsMemory=0 exitsWatchdog=0")
    }

    @Test func aDayWithAbnormalMemoryOrWatchdogExitsIsANotice() {
        #expect(DailyHealth(at: launchTime, normalExits: 3, abnormalExits: 1, memoryExits: 0, watchdogExits: 0).event.level == .notice)
        #expect(DailyHealth(at: launchTime, normalExits: 3, abnormalExits: 0, memoryExits: 2, watchdogExits: 0).event.level == .notice)
        #expect(DailyHealth(at: launchTime, normalExits: 3, abnormalExits: 0, memoryExits: 0, watchdogExits: 1).event.level == .notice)
    }

    @Test func aDayWithNothingToReportIsNotLogged() {
        #expect(DailyHealth(at: launchTime, normalExits: 0, abnormalExits: 0, memoryExits: 0, watchdogExits: 0).isEmpty)
        #expect(DailyHealth(at: launchTime, normalExits: 1, abnormalExits: 0, memoryExits: 0, watchdogExits: 0).isEmpty == false)
    }

    @Test func negativeCountsAreKeptAtZero() {
        let day = DailyHealth(at: launchTime, normalExits: -4, abnormalExits: 2, memoryExits: 0, watchdogExits: 0)
        #expect(day.normalExits == 0)
    }

    // MARK: A launch the system made in the background is not a run on screen (#333)

    @Test func aBackgroundLaunchIsNotMarkedOnScreen() {
        let result = RunTracker.launch(previous: nil, build: "9", now: launchTime, inForeground: false)
        #expect(result.record.wasActive == false)
        #expect(result.endedUnexpectedly == false)
    }

    @Test func aForegroundLaunchIsStillMarkedOnScreen() {
        // A crash while the app is still starting up is caught.
        #expect(RunTracker.launch(previous: nil, build: "9", now: launchTime, inForeground: true).record.wasActive)
    }

    @Test func theLogOfTheReportDoesNotReportAnUnexpectedExit() {
        // Foreground run, left cleanly; the system launches the app in the background and later ends the process; the next real launch.
        var record = RunTracker.launch(previous: nil, build: "9", now: launchTime, inForeground: true).record
        record = RunTracker.leftTheScreen(record)                                                  // 13:57, to the background
        let background = RunTracker.launch(previous: record, build: "9", now: launchTime.addingTimeInterval(2_500), inForeground: false)
        #expect(background.endedUnexpectedly == false)
        let next = RunTracker.launch(previous: background.record, build: "9", now: launchTime.addingTimeInterval(8_000), inForeground: true)
        #expect(next.endedUnexpectedly == false)                                                    // 16:06: was a false alarm
    }

    @Test func aRealUnexpectedEndIsStillReportedAfterABackgroundLaunchInBetween() {
        // On screen, then ended without leaving it; a background launch; then a foreground launch: the earlier end was real.
        let onScreen = RunTracker.launch(previous: nil, build: "9", now: launchTime, inForeground: true).record
        let background = RunTracker.launch(previous: onScreen, build: "9", now: launchTime.addingTimeInterval(60), inForeground: false)
        #expect(background.endedUnexpectedly)
    }

    @Test func comingToTheScreenAfterABackgroundLaunchMarksTheRunOnScreen() {
        let background = RunTracker.launch(previous: nil, build: "9", now: launchTime, inForeground: false).record
        let active = RunTracker.becameActive(background, now: launchTime.addingTimeInterval(30))
        #expect(active.wasActive)
        #expect(RunTracker.launch(previous: active, build: "9", now: launchTime.addingTimeInterval(90), inForeground: true).endedUnexpectedly)
    }

    @Test func theLaunchEventSaysWhetherItWasInTheForeground() {
        #expect(DiagnosticKey.foreground.rawValue == "foreground")
        let event = RunTracker.launchedEvent(inForeground: false, at: launchTime)
        #expect(event.name == .appLaunched)
        #expect(event.line(timeZone: utc) == "2026-09-22 18:00:00 app.launched foreground=false")
    }

    // MARK: Why it died, and what happened in the background (#416)

    @Test func aTerminationReasonIsKeptAsItsNamespaceAndCodeOnly() {
        #expect(DiagnosticValue.termination("Namespace RUNNINGBOARD, Code 0xdead10cc")?.text == "RUNNINGBOARD 0xdead10cc")
        #expect(DiagnosticValue.termination("Namespace SPRINGBOARD, Code 0x8badf00d")?.text == "SPRINGBOARD 0x8badf00d")
        #expect(DiagnosticValue.termination("Namespace SIGNAL, Code 11")?.text == "SIGNAL 11")
        #expect(DiagnosticValue.termination("Namespace SIGNAL, Code 11 Segmentation fault: 11 while saving Call the clinic back")?.text == "SIGNAL 11",
                "anything after the code is dropped, so a title or a path can't get in")
    }

    @Test func textThatIsNotANamespaceAndCodeIsNeverKept() {
        #expect(DiagnosticValue.termination(nil) == nil)
        #expect(DiagnosticValue.termination("") == nil)
        #expect(DiagnosticValue.termination("Call the clinic back") == nil)
        #expect(DiagnosticValue.termination("Namespace lower, Code 0x1") == nil, "a namespace is capitals")
        #expect(DiagnosticValue.termination("Namespace " + String(repeating: "A", count: 40) + ", Code 1") == nil, "and short")
    }

    @Test func aCrashEventCarriesItsTerminationReasonWhenThereIsOne() {
        let withReason = SystemDiagnostic(kind: .crash, at: when, exceptionType: 10, exceptionCode: 0, signal: 9, build: 13,
                                          terminationReason: "Namespace RUNNINGBOARD, Code 0xdead10cc").event
        #expect(withReason.line(timeZone: utc).contains("termination=RUNNINGBOARD 0xdead10cc"))
        let without = SystemDiagnostic(kind: .crash, at: when, exceptionType: 10, exceptionCode: 0, signal: 9, build: 13).event
        #expect(!without.line(timeZone: utc).contains("termination"))
    }

    @Test func theBackgroundExitCountsJoinTheDailyLineOnlyWhenTheyAreNotZero() {
        let quiet = DailyHealth(at: when, normalExits: 3, abnormalExits: 0, memoryExits: 0, watchdogExits: 0)
        #expect(!quiet.event.line(timeZone: utc).contains("bg"))
        let trouble = DailyHealth(at: when, normalExits: 3, abnormalExits: 0, memoryExits: 0, watchdogExits: 0,
                                  backgroundAbnormalExits: 1, backgroundLockedFileExits: 2, backgroundTaskTimeoutExits: 0)
        let line = trouble.event.line(timeZone: utc)
        #expect(line.contains("bgAbnormal=1") && line.contains("bgLockedFile=2"))
        #expect(!line.contains("bgTaskTimeout"))
        #expect(trouble.event.level == .notice, "any background trouble makes the day a notice")
    }

    @Test func aDayWithOnlyBackgroundTroubleIsStillWorthALine() {
        let onlyBackground = DailyHealth(at: when, normalExits: 0, abnormalExits: 0, memoryExits: 0, watchdogExits: 0, backgroundMemoryExits: 1)
        #expect(!onlyBackground.isEmpty)
    }

    @Test func goingToTheBackgroundIsAnAppEventAndSyncEventsCanSayWhetherTheAppWasAway() {
        #expect(DiagnosticName.appBackground.rawValue == "app.background")
        #expect(DiagnosticName.appBackground.category == .app)
        let away = DiagnosticEvent(at: when, name: .syncImport, fields: [.init(.ok, .flag(true)), .init(.foreground, .flag(false))])
        #expect(away.line(timeZone: utc).hasSuffix("sync.import ok=true foreground=false"))
    }
}
