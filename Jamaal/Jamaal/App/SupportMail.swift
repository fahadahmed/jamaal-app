//
//  SupportMail.swift
//  Jamaal
//

import Foundation

/// A message to support with the diagnostics already in it (Settings → iCloud sync → Email support). The details hold no titles,
/// notes or places (docs/architecture/observability.md); a person writes above them and presses send themselves.
enum SupportMail {
    static let address = "support@jamaal.app"
    static let subject = "Jamaal feedback"

    /// A mail link is a URL, and a very long one stops working in some mail apps: past this the details are cut short.
    static let maxLength = 6_000

    static func url(details: String) -> URL? {
        func build(_ details: String) -> URL? {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = address
            components.queryItems = [
                URLQueryItem(name: "subject", value: subject),
                URLQueryItem(name: "body", value: "\n\n" + details),
            ]
            return components.url
        }
        guard let whole = build(details) else { return nil }
        if whole.absoluteString.count <= maxLength { return whole }
        // Keep the start (this build and the sync state, which matter most) and say it was cut.
        var lines = details.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while lines.count > 1 {
            lines.removeLast(max(1, lines.count / 8))
            if let url = build(lines.joined(separator: "\n") + "\n…trimmed"), url.absoluteString.count <= maxLength { return url }
        }
        return build("…trimmed")
    }
}
