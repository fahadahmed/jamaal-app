//
//  SystemReports.swift
//  Jamaal
//

import Foundation
import JamaalCore
#if canImport(MetricKit)
import MetricKit
#endif

/// How the last run ended, remembered on this device (docs/architecture/observability.md, layer 3). At launch it says whether the
/// run before it was still on screen when it ended; that is logged as `app.unexpectedExit`, and (in a TestFlight or App Store build)
/// it raises the one-time card on Today. Debug builds log it but never show the card: stopping the app in Xcode looks the same.
enum RunLifecycle {
    private static let recordKey = "runRecord"
    private static let noticeKey = "exitNotice"
    private static let defaults = UserDefaults.standard

    private static var build: String { (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?" }

    static func launched(now: Date = .now) {
        let previous = load(RunRecord.self, key: recordKey)
        let launch = RunTracker.launch(previous: previous, build: build, now: now)
        save(launch.record, key: recordKey)
        guard launch.endedUnexpectedly, let previousBuild = launch.previousBuild else { return }
        Diag.shared.record(RunTracker.unexpectedExitEvent(previousBuild: previousBuild, at: now))
        if BuildChannel.current != .debug {
            var notice = load(ExitNotice.self, key: noticeKey) ?? ExitNotice()
            notice.detected(at: now)
            save(notice, key: noticeKey)
        }
    }

    static func becameActive(now: Date = .now) {
        guard let record = load(RunRecord.self, key: recordKey) else { return launched(now: now) }
        save(RunTracker.becameActive(record, now: now), key: recordKey)
    }

    static func leftTheScreen() {
        guard let record = load(RunRecord.self, key: recordKey) else { return }
        save(RunTracker.leftTheScreen(record), key: recordKey)
    }

    static func noticeIsShown(now: Date = .now) -> Bool {
        #if DEBUG
        if DebugLaunch.exitNotice { return true }
        #endif
        return (load(ExitNotice.self, key: noticeKey) ?? ExitNotice()).isShown(now: now)
    }

    static func noticeAnswered() {
        var notice = load(ExitNotice.self, key: noticeKey) ?? ExitNotice()
        notice.answered()
        save(notice, key: noticeKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

enum ExitNoticeCopy {
    static let text = "Jamaal didn't close properly last time. A short note about what you were doing helps fix it."
    static let send = "Send a note"
    static let notNow = "Not now"
}

#if canImport(MetricKit)
/// Receives MetricKit's reports (a crash, a hang, a CPU or disk-write exception, and a day's exit counts) and records the numbers
/// that matter as events. **Nothing is kept but numbers**: no call stack, no termination text. Nothing leaves the device; the events
/// reach us only if a person shares their log. Delivery is about once a day, usually at a later launch.
final class MetricKitReceiver: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = MetricKitReceiver()

    func start() { MXMetricManager.shared.add(self) }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let at = payload.timeStampEnd
            for crash in payload.crashDiagnostics ?? [] {
                Diag.shared.record(SystemDiagnostic(
                    kind: .crash, at: at, exceptionType: crash.exceptionType?.intValue, exceptionCode: crash.exceptionCode?.intValue,
                    signal: crash.signal?.intValue, build: SystemDiagnostic.build(from: crash.metaData.applicationBuildVersion)).event)
            }
            for hang in payload.hangDiagnostics ?? [] {
                Diag.shared.record(SystemDiagnostic(
                    kind: .hang, at: at, durationMs: Int(hang.hangDuration.converted(to: .milliseconds).value),
                    build: SystemDiagnostic.build(from: hang.metaData.applicationBuildVersion)).event)
            }
            for cpu in payload.cpuExceptionDiagnostics ?? [] {
                Diag.shared.record(SystemDiagnostic(kind: .cpuException, at: at, build: SystemDiagnostic.build(from: cpu.metaData.applicationBuildVersion)).event)
            }
            for disk in payload.diskWriteExceptionDiagnostics ?? [] {
                Diag.shared.record(SystemDiagnostic(kind: .diskWriteException, at: at, build: SystemDiagnostic.build(from: disk.metaData.applicationBuildVersion)).event)
            }
        }
    }

    #if os(iOS)
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let exits = payload.applicationExitMetrics?.foregroundExitData else { continue }
            let day = DailyHealth(
                at: payload.timeStampEnd, normalExits: exits.cumulativeNormalAppExitCount,
                abnormalExits: exits.cumulativeAbnormalExitCount + exits.cumulativeBadAccessExitCount + exits.cumulativeIllegalInstructionExitCount,
                memoryExits: exits.cumulativeMemoryResourceLimitExitCount, watchdogExits: exits.cumulativeAppWatchdogExitCount)
            if !day.isEmpty { Diag.shared.record(day.event) }
        }
    }
    #endif
}
#endif
