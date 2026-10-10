import Foundation

/// The `jamaal://` links a widget (and later the watch) opens the app with: `jamaal://today`, `jamaal://plan`
/// (Night Planning, always for tomorrow) and `jamaal://task/<id>`. A link becomes the same `NotificationRoute` a
/// notification tap uses, so there is one path in. Anything unrecognised is ignored rather than guessed at, since
/// a link comes from outside the app.
public enum JamaalLink: Equatable, Sendable {
    case today
    case plan
    case task(UUID)

    public static let scheme = "jamaal"

    public var url: URL {
        switch self {
        case .today: URL(string: "jamaal://today")!
        case .plan: URL(string: "jamaal://plan")!
        case .task(let id): URL(string: "jamaal://task/\(id.uuidString)")!
        }
    }

    /// The route for this link; `today` is the current logical day (tomorrow's plan is the day after).
    public func route(today: CalendarDate) -> NotificationRoute {
        switch self {
        case .today: .today
        case .plan: .planning(today.addingDays(1))
        case .task(let id): .task(id)
        }
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch (host, parts.count) {
        case ("today", 0): self = .today
        case ("plan", 0): self = .plan
        case ("task", 1):
            guard let id = UUID(uuidString: parts[0]) else { return nil }
            self = .task(id)
        default: return nil
        }
    }

    public static func route(from url: URL, today: CalendarDate) -> NotificationRoute? {
        JamaalLink(url: url)?.route(today: today)
    }
}
