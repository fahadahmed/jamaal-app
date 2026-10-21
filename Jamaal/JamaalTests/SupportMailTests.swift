//
//  SupportMailTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// The Email support button opens a message to support with the diagnostics already in it.
struct SupportMailTests {

    private func parts(_ url: URL) -> (to: String, subject: String, body: String) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        return (components.path, items["subject"] ?? "", items["body"] ?? "")
    }

    @Test func theMessageGoesToSupportWithASubjectAndTheDetailsAsTheBody() throws {
        let url = try #require(SupportMail.url(details: "Device: iPad\nSync: on"))
        #expect(url.scheme == "mailto")
        let p = parts(url)
        #expect(p.to == "support@jamaal.app")
        #expect(p.subject == "Jamaal feedback")
        #expect(p.body.hasSuffix("Device: iPad\nSync: on"))
    }

    @Test func theBodyLeavesRoomToWriteAboveTheDetails() throws {
        let body = parts(try #require(SupportMail.url(details: "X"))).body
        #expect(body.hasPrefix("\n\n"), "two blank lines first, so a person types above what was filled in")
    }

    @Test func specialCharactersSurviveTheTrip() throws {
        let details = "Last problem: CKErrorDomain 9 (sending) & more=100% #1 ünï"
        #expect(parts(try #require(SupportMail.url(details: details))).body.hasSuffix(details))
    }

    @Test func aVeryLongReportIsTrimmedKeepingItsStartSoTheLinkStaysUsable() throws {
        let long = (0..<2000).map { "line \($0) of the events" }.joined(separator: "\n")
        let url = try #require(SupportMail.url(details: long))
        #expect(url.absoluteString.count <= SupportMail.maxLength)
        let body = parts(url).body
        #expect(body.contains("line 0 of the events"), "the start (the build and sync state) is kept")
        #expect(body.contains("…trimmed"), "and it says so")
    }

    @Test func theAddressIsTheOneOnTheWebsite() {
        #expect(SupportMail.address == "support@jamaal.app")
    }
}
