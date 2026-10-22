import Foundation

// The on-device event log (docs/architecture/observability.md). **Events, never content:** an event is a name from a fixed list,
// and fields whose keys are a fixed list and whose values can only be a count, a flag, a short id or an error's domain and code.
// There is no way to put a title, a note, a name or a place in one, so a log can be shared, and (with the owner's switch) reported,
// without ever carrying what a person planned.

public enum DiagnosticCategory: String, Codable, CaseIterable, Sendable {
    case app, sync, engine, focus, anchors, habits, widgets, store, notifications, purchases
}

public enum DiagnosticLevel: String, Codable, Sendable {
    case info, notice, error
}

/// Every event the app can log. A new one is added here, on purpose, with its category.
public enum DiagnosticName: String, Codable, CaseIterable, Sendable {
    case appLaunched = "app.launched"
    case appActive = "app.active"
    case syncSetup = "sync.setup"
    case syncImport = "sync.import"
    case syncExport = "sync.export"
    case engineTick = "engine.tick"
    case engineTickFailed = "engine.tickFailed"
    case focusBegan = "focus.began"
    case focusFinished = "focus.finished"
    case anchorsFinalised = "anchors.finalised"
    case storeOpened = "store.opened"
    case storeOpenFailed = "store.openFailed"
    case widgetsReloaded = "widgets.reloaded"

    public var category: DiagnosticCategory {
        switch self {
        case .appLaunched, .appActive: .app
        case .syncSetup, .syncImport, .syncExport: .sync
        case .engineTick, .engineTickFailed: .engine
        case .focusBegan, .focusFinished: .focus
        case .anchorsFinalised: .anchors
        case .storeOpened, .storeOpenFailed: .store
        case .widgetsReloaded: .widgets
        }
    }
}

/// The names of an event's fields: a fixed list too.
public enum DiagnosticKey: String, Codable, CaseIterable, Sendable {
    case seeded, merged, generated, removed, finalised, deferrals, days, durationMs
    case ok, errorCode
    case window, entry, minutes
    case inMemory, syncOn
}

/// What a field can hold. There is no initialiser that takes text: only these, so content can't get in.
public struct DiagnosticValue: Codable, Equatable, Sendable {
    public let text: String
    private init(_ text: String) { self.text = text }

    public static func count(_ n: Int) -> DiagnosticValue { .init(String(n)) }
    public static func flag(_ b: Bool) -> DiagnosticValue { .init(b ? "true" : "false") }
    /// The first four characters of a UUID: enough to match two devices, not enough to identify anything.
    public static func id(_ uuid: UUID) -> DiagnosticValue { .init(String(uuid.uuidString.prefix(4))) }
    /// An error's domain and code. Its message is dropped: it can hold anything.
    public static func error(_ error: Error) -> DiagnosticValue {
        let ns = error as NSError
        return .init("\(ns.domain) \(ns.code)")
    }

    /// The 14 CloudKit record types the schema makes (SwiftData prefixes each model with `CD_`). Only these names are ever kept from
    /// an error message, so a message that holds a title can't leak one.
    public static let knownRecordTypes: Set<String> = [
        "CD_TaskItem", "CD_TaskCategory", "CD_DeferralRecord", "CD_WorkSession", "CD_Habit", "CD_HabitGroup", "CD_HabitTimeWindow",
        "CD_HabitEntry", "CD_AnchorRule", "CD_Anchor", "CD_UserSettings", "CD_DayPlan", "CD_NightPlanningSession", "CD_NudgeLog",
    ]

    /// Like `error`, and for a partial failure (iCloud took some records and refused others) also each refused record's error code with
    /// how many, and which of our record types were refused: "CKErrorDomain 2 items=12x2,15x1 types=CD_Habit". Messages are dropped.
    public static func detailedError(_ error: Error) -> DiagnosticValue {
        let ns = error as NSError
        var text = "\(ns.domain) \(ns.code)"
        guard let items = ns.userInfo["CKPartialErrors"] as? [AnyHashable: Error], !items.isEmpty else { return .init(text) }
        var counts: [Int: Int] = [:]
        var types = Set<String>()
        for item in items.values {
            let e = item as NSError
            counts[e.code, default: 0] += 1
            for word in e.localizedDescription.split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") }) where knownRecordTypes.contains(String(word)) {
                types.insert(String(word))
            }
        }
        text += " items=" + counts.keys.sorted().map { "\($0)x\(counts[$0]!)" }.joined(separator: ",")
        if !types.isEmpty { text += " types=" + types.sorted().joined(separator: ",") }
        return .init(text)
    }
}

public struct DiagnosticEvent: Codable, Equatable, Sendable {
    public struct Field: Codable, Equatable, Sendable {
        public var key: DiagnosticKey
        public var value: DiagnosticValue
        public init(_ key: DiagnosticKey, _ value: DiagnosticValue) { self.key = key; self.value = value }
    }

    public var at: Date
    public var name: DiagnosticName
    public var level: DiagnosticLevel
    public var fields: [Field]

    public init(at: Date, name: DiagnosticName, level: DiagnosticLevel = .info, fields: [Field] = []) {
        self.at = at; self.name = name; self.level = level; self.fields = fields
    }

    public var category: DiagnosticCategory { name.category }

    /// "2026-10-21 14:03:41 engine.tick merged=2 durationMs=41"; a notice or an error is marked after the time.
    public func line(timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var parts = [formatter.string(from: at)]
        if level != .info { parts.append(level.rawValue.uppercased()) }
        parts.append(name.rawValue)
        parts += fields.map { "\($0.key.rawValue)=\($0.value.text)" }
        return parts.joined(separator: " ")
    }
}

/// The last few events, oldest first. A value type: the app keeps one and saves it as JSON on the device.
public struct DiagnosticLog: Codable, Equatable, Sendable {
    public private(set) var capacity: Int
    public private(set) var events: [DiagnosticEvent]

    public init(capacity: Int = 200) {
        self.capacity = max(0, capacity)
        events = []
    }

    public mutating func append(_ event: DiagnosticEvent) {
        guard capacity > 0 else { return }
        events.append(event)
        if events.count > capacity { events.removeFirst(events.count - capacity) }
    }

    public func recent(_ count: Int) -> [DiagnosticEvent] {
        Array(events.suffix(max(0, count)))
    }

    // A log written by another version may hold an event this one doesn't know: skip it, never fail to load.
    private struct Lenient: Decodable {
        let event: DiagnosticEvent?
        init(from decoder: Decoder) throws { event = try? DiagnosticEvent(from: decoder) }
    }

    private enum CodingKeys: String, CodingKey { case capacity, events }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cap = max(0, try container.decode(Int.self, forKey: .capacity))
        capacity = cap
        events = Array(try container.decode([Lenient].self, forKey: .events).compactMap(\.event).suffix(cap))
    }
}

/// Which build this is, for the top of a report.
public struct DiagnosticEnvironment: Equatable, Sendable {
    public enum Channel: String, Sendable { case debug, testFlight, appStore }

    public var appVersion: String
    public var build: String
    public var os: String
    public var device: String
    public var channel: Channel

    public init(appVersion: String, build: String, os: String, device: String, channel: Channel) {
        self.appVersion = appVersion; self.build = build; self.os = os; self.device = device; self.channel = channel
    }
}

public enum DiagnosticsCopy {

    public static func environmentLines(_ env: DiagnosticEnvironment) -> [String] {
        let channel: String = switch env.channel {
        case .debug: "debug build"
        case .testFlight: "TestFlight"
        case .appStore: "App Store"
        }
        return ["App: \(env.appVersion) (\(env.build)), \(channel)", "System: \(env.os)", "Model: \(env.device)"]
    }

    public static func eventLines(_ log: DiagnosticLog, limit: Int, timeZone: TimeZone = .current) -> [String] {
        let recent = log.recent(limit)
        guard !recent.isEmpty else { return ["Recent events: none yet"] }
        return ["Recent events (last \(recent.count) of \(log.events.count)):"] + recent.map { $0.line(timeZone: timeZone) }
    }
}
