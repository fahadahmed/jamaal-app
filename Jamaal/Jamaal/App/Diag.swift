//
//  Diag.swift
//  Jamaal
//

import Foundation
import os
import JamaalCore

/// The app's diagnostics: one call records an event to Apple's unified log (so Console and a sysdiagnose see it) and to a small buffer
/// of the last events kept in a file on this device. An event is a fixed name with ids, counts and codes, never content
/// (docs/architecture/observability.md), so nothing here needs redacting. Nothing leaves the device unless the person shares it.
final class Diag: @unchecked Sendable {
    static let shared = Diag()

    private let lock = NSLock()
    private var log = DiagnosticLog()
    private var saveQueued = false
    private let fileURL: URL?

    private static let loggers: [DiagnosticCategory: Logger] = Dictionary(
        uniqueKeysWithValues: DiagnosticCategory.allCases.map { ($0, Logger(subsystem: "dev.fhdamd.Jamaal", category: $0.rawValue)) })

    private init() {
        fileURL = Self.shouldKeepAFile ? Self.defaultFile() : nil
        if let fileURL, let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode(DiagnosticLog.self, from: data) {
            log = saved
        }
    }

    /// UI tests and the gallery leave no file behind.
    private static var shouldKeepAFile: Bool {
        #if DEBUG
        return !DebugLaunch.inMemory
        #else
        return true
        #endif
    }

    private static func defaultFile() -> URL? {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return support.appendingPathComponent("Jamaal-diagnostics.json")
    }

    // MARK: Recording

    func record(_ name: DiagnosticName, level: DiagnosticLevel = .info, _ fields: DiagnosticEvent.Field...) {
        record(name, level: level, fields)
    }

    func record(_ name: DiagnosticName, level: DiagnosticLevel = .info, _ fields: [DiagnosticEvent.Field]) {
        record(DiagnosticEvent(at: .now, name: name, level: level, fields: fields))
    }

    /// An event built elsewhere (a system report keeps the time it happened, not the time it was read).
    func record(_ event: DiagnosticEvent) {
        let level = event.level
        let line = event.line()
        let logger = Self.loggers[event.category] ?? Logger(subsystem: "dev.fhdamd.Jamaal", category: "app")
        switch level {
        case .info: logger.info("\(line, privacy: .public)")
        case .notice: logger.notice("\(line, privacy: .public)")
        case .error: logger.error("\(line, privacy: .public)")
        }
        lock.lock()
        log.append(event)
        let needsSave = fileURL != nil && !saveQueued
        if needsSave { saveQueued = true }
        lock.unlock()
        if needsSave { DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) { [self] in save() } }
    }

    /// Writes the buffer now (the app is leaving the screen).
    func save() {
        lock.lock()
        let snapshot = log
        saveQueued = false
        lock.unlock()
        guard let fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Reading

    /// The text of a report: this build, then the last events.
    func reportLines(eventLimit: Int = 50) -> [String] {
        lock.lock()
        let snapshot = log
        lock.unlock()
        return DiagnosticsCopy.environmentLines(DiagnosticEnvironment.current) + DiagnosticsCopy.eventLines(snapshot, limit: eventLimit)
    }
}

extension DiagnosticEnvironment {
    /// This build and device, read from the bundle and the system.
    nonisolated static var current: DiagnosticEnvironment {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = ProcessInfo.processInfo.operatingSystemVersion
        #if os(macOS)
        let system = "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        let key = "hw.model"
        #else
        let system = "iOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"                  // the model line says iPad or iPhone
        let key = "hw.machine"
        #endif
        return DiagnosticEnvironment(
            appVersion: info["CFBundleShortVersionString"] as? String ?? "?", build: info["CFBundleVersion"] as? String ?? "?",
            os: system, device: sysctlString(key) ?? "unknown", channel: channel)
    }

    nonisolated private static var channel: Channel { BuildChannel.current.diagnosticChannel }

    nonisolated private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
