import Foundation

// What the system tells the app about how it ended (docs/architecture/observability.md, layer 3), as the same fixed, content-free
// events as the rest of the log. MetricKit and the app lifecycle are read in the app; everything that decides what is kept is here.
// **Numbers only:** no call stack, no termination text, nothing a person typed.

/// One crash, hang or exception that MetricKit reported.
public struct SystemDiagnostic: Equatable, Sendable {
    public enum Kind: Sendable { case crash, hang, cpuException, diskWriteException }

    public var kind: Kind
    /// The end of the window the report covers: when it happened, to within about a day.
    public var at: Date
    public var exceptionType: Int?
    public var exceptionCode: Int?
    public var signal: Int?
    /// A hang's length.
    public var durationMs: Int?
    public var build: Int?
    /// The system's reason for a crash, as MetricKit words it; only its namespace and code are ever kept (`DiagnosticValue.termination`).
    public var terminationReason: String?

    public init(kind: Kind, at: Date, exceptionType: Int? = nil, exceptionCode: Int? = nil, signal: Int? = nil,
                durationMs: Int? = nil, build: Int? = nil, terminationReason: String? = nil) {
        self.kind = kind; self.at = at
        self.exceptionType = exceptionType; self.exceptionCode = exceptionCode; self.signal = signal
        self.durationMs = durationMs; self.build = build; self.terminationReason = terminationReason
    }

    /// The build number when it is a whole number ("7"), nothing otherwise: free text is never kept.
    public static func build(from text: String?) -> Int? {
        guard let text, !text.isEmpty, text.allSatisfy(\.isASCII), text.allSatisfy(\.isNumber) else { return nil }
        return Int(text)
    }

    public var event: DiagnosticEvent {
        let name: DiagnosticName
        let level: DiagnosticLevel
        switch kind {
        case .crash: name = .systemCrash; level = .error
        case .hang: name = .systemHang; level = .notice
        case .cpuException: name = .systemCPUException; level = .notice
        case .diskWriteException: name = .systemDiskWrite; level = .notice
        }
        var fields: [DiagnosticEvent.Field] = []
        if let exceptionType { fields.append(.init(.exceptionType, .count(exceptionType))) }
        if let exceptionCode { fields.append(.init(.exceptionCode, .count(exceptionCode))) }
        if let signal { fields.append(.init(.signal, .count(signal))) }
        if let durationMs, durationMs >= 0 { fields.append(.init(.durationMs, .count(durationMs))) }
        if let build { fields.append(.init(.build, .count(build))) }
        if let reason = DiagnosticValue.termination(terminationReason) { fields.append(.init(.termination, reason)) }
        return DiagnosticEvent(at: at, name: name, level: level, fields: fields)
    }
}

/// Whether the app was on screen when it was last closed. Set when it becomes active, cleared when it leaves the screen or quits; a
/// launch that finds it still set means the last run ended without that (a crash, a hang the system ended, a memory kill, a force-quit
/// from the app switcher, a flat battery), so it is never described as a crash.
public struct RunRecord: Codable, Equatable, Sendable {
    public var wasActive: Bool
    public var build: String
    public var since: Date

    public init(wasActive: Bool, build: String, since: Date) {
        self.wasActive = wasActive; self.build = build; self.since = since
    }
}

public enum RunTracker {
    public struct Launch: Equatable, Sendable {
        public var record: RunRecord
        public var endedUnexpectedly: Bool
        public var previousBuild: String?
    }

    /// A launch: the run before it ended unexpectedly if it was still active **and was the same build** (installing an update closes
    /// the old build while it is open, which is not a problem). `inForeground` is false when the system started the app in the
    /// background (an iCloud change, a widget refresh) and it has not come to the screen: that run is **not** marked on screen, because
    /// nothing would ever clear the mark (the scene phase never changes) and the next launch would report a crash that did not happen (#333).
    public static func launch(previous: RunRecord?, build: String, now: Date, inForeground: Bool = true) -> Launch {
        let unexpected = previous.map { $0.wasActive && $0.build == build } ?? false
        return Launch(record: RunRecord(wasActive: inForeground, build: build, since: now), endedUnexpectedly: unexpected,
                      previousBuild: unexpected ? previous?.build : nil)
    }

    /// `app.launched`, with whether the launch was in the foreground, so a report says which kind it was.
    public static func launchedEvent(inForeground: Bool, at: Date) -> DiagnosticEvent {
        DiagnosticEvent(at: at, name: .appLaunched, fields: [.init(.foreground, .flag(inForeground))])
    }

    public static func leftTheScreen(_ record: RunRecord) -> RunRecord {
        var copy = record
        copy.wasActive = false
        return copy
    }

    public static func becameActive(_ record: RunRecord, now: Date) -> RunRecord {
        RunRecord(wasActive: true, build: record.build, since: now)
    }

    public static func unexpectedExitEvent(previousBuild: String, at: Date) -> DiagnosticEvent {
        var fields: [DiagnosticEvent.Field] = []
        if let build = SystemDiagnostic.build(from: previousBuild) { fields.append(.init(.build, .count(build))) }
        return DiagnosticEvent(at: at, name: .appUnexpectedExit, level: .notice, fields: fields)
    }
}

/// The one-time card on Today after an unexpected end: *Send a note*, or *Not now*. It fades by itself after three days, so it never nags.
public struct ExitNotice: Codable, Equatable, Sendable {
    public static let lifetime: TimeInterval = 3 * 86_400

    public private(set) var detectedAt: Date?

    public init() {}

    public mutating func detected(at date: Date) { detectedAt = date }

    /// Answered: the note was sent, or the person said not now.
    public mutating func answered() { detectedAt = nil }

    public func isShown(now: Date) -> Bool {
        guard let detectedAt, now >= detectedAt else { return false }
        return now.timeIntervalSince(detectedAt) <= Self.lifetime
    }
}

/// One device's day, from MetricKit's exit counts: how many times the app ended normally, abnormally, for memory or to the watchdog.
public struct DailyHealth: Equatable, Sendable {
    public var at: Date
    public private(set) var normalExits: Int
    public private(set) var abnormalExits: Int
    public private(set) var memoryExits: Int
    public private(set) var watchdogExits: Int
    // Exits while the app was in the background (MetricKit's background exit data). A background death is the one a person never sees,
    // so these say what the foreground counts can't: a crash while away, memory, the watchdog, being suspended while holding a file
    // lock (the 0xdead10cc kill, which a store in the App Group can meet), and a background task that ran out of time.
    public private(set) var backgroundAbnormalExits: Int
    public private(set) var backgroundMemoryExits: Int
    public private(set) var backgroundWatchdogExits: Int
    public private(set) var backgroundLockedFileExits: Int
    public private(set) var backgroundTaskTimeoutExits: Int

    public init(
        at: Date, normalExits: Int, abnormalExits: Int, memoryExits: Int, watchdogExits: Int,
        backgroundAbnormalExits: Int = 0, backgroundMemoryExits: Int = 0, backgroundWatchdogExits: Int = 0,
        backgroundLockedFileExits: Int = 0, backgroundTaskTimeoutExits: Int = 0
    ) {
        self.at = at
        self.normalExits = max(0, normalExits); self.abnormalExits = max(0, abnormalExits)
        self.memoryExits = max(0, memoryExits); self.watchdogExits = max(0, watchdogExits)
        self.backgroundAbnormalExits = max(0, backgroundAbnormalExits); self.backgroundMemoryExits = max(0, backgroundMemoryExits)
        self.backgroundWatchdogExits = max(0, backgroundWatchdogExits); self.backgroundLockedFileExits = max(0, backgroundLockedFileExits)
        self.backgroundTaskTimeoutExits = max(0, backgroundTaskTimeoutExits)
    }

    private var backgroundTrouble: Int {
        backgroundAbnormalExits + backgroundMemoryExits + backgroundWatchdogExits + backgroundLockedFileExits + backgroundTaskTimeoutExits
    }

    /// Nothing happened worth a line.
    public var isEmpty: Bool { normalExits + abnormalExits + memoryExits + watchdogExits + backgroundTrouble == 0 }

    public var event: DiagnosticEvent {
        let trouble = abnormalExits + memoryExits + watchdogExits + backgroundTrouble > 0
        var fields: [DiagnosticEvent.Field] = [
            .init(.exitsNormal, .count(normalExits)), .init(.exitsAbnormal, .count(abnormalExits)),
            .init(.exitsMemory, .count(memoryExits)), .init(.exitsWatchdog, .count(watchdogExits)),
        ]
        // Only what happened: a quiet day's line stays as short as it was.
        for (key, count) in [(DiagnosticKey.bgAbnormal, backgroundAbnormalExits), (.bgMemory, backgroundMemoryExits),
                             (.bgWatchdog, backgroundWatchdogExits), (.bgLockedFile, backgroundLockedFileExits),
                             (.bgTaskTimeout, backgroundTaskTimeoutExits)] where count > 0 {
            fields.append(.init(key, .count(count)))
        }
        return DiagnosticEvent(at: at, name: .systemDaily, level: trouble ? .notice : .info, fields: fields)
    }
}
