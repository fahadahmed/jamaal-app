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
}

