import Foundation
import Testing
@testable import JamaalCore

/// A Mac stopped syncing with `NSCocoaErrorDomain 134400` at setup and the report could not say why (#331). The account status is
/// logged beside a failed setup, in words from a fixed list, and the status screen says something a person can act on.
struct SyncAccountTests {

    private let utc = TimeZone(identifier: "UTC")!
    private let at = Date(timeIntervalSince1970: 1_790_000_000)

    // MARK: The account, as a fixed word

    @Test func everyAccountStateIsOneFixedWord() {
        #expect(DiagnosticValue.account(.available).text == "available")
        #expect(DiagnosticValue.account(.noAccount).text == "noAccount")
        #expect(DiagnosticValue.account(.restricted).text == "restricted")
        #expect(DiagnosticValue.account(.temporarilyUnavailable).text == "temporarilyUnavailable")
        #expect(DiagnosticValue.account(.unknown).text == "unknown")
    }

    @Test func theAccountEventIsALineInTheSyncCategory() {
        #expect(DiagnosticName.syncAccount.category == .sync)
        #expect(DiagnosticName.syncAccount.rawValue == "sync.account")
        let event = DiagnosticEvent(at: at, name: .syncAccount, level: .notice, fields: [.init(.account, .account(.noAccount))])
        #expect(event.line(timeZone: utc) == "2026-09-21 14:13:20 NOTICE sync.account account=noAccount")
    }

    // MARK: What the status screen says

    @Test func aTemporarilyUnavailableAccountIsSaidCalmly() {
        let headline = SyncStatusCopy.headline(isOn: true, account: .temporarilyUnavailable, activity: SyncActivity(), now: at)
        #expect(headline == "iCloud is temporarily unavailable on this device.")
        #expect(SyncStatusCopy.accountText(.temporarilyUnavailable) == "temporarily unavailable")
    }

    @Test func aSetupThatCouldNotStartHasAPlainHint() throws {
        let hint = try #require(SyncStatusCopy.hint(forError: "NSCocoaErrorDomain 134400", kind: .setup))
        #expect(hint.contains("couldn't start iCloud sync"))
        #expect(hint.contains("signed in to iCloud"))
        #expect(hint.contains("quit and reopen"))
    }

    @Test func theHintForASetupFailureDoesNotBlameTheAppOrThePerson() throws {
        let hint = try #require(SyncStatusCopy.hint(forError: "NSCocoaErrorDomain 134400", kind: .setup))
        #expect(!hint.lowercased().contains("your fault"))
        #expect(!hint.lowercased().contains("crash"))
    }

    @Test func aCodeWeDoNotUnderstandStillHasNoHint() {
        #expect(SyncStatusCopy.hint(forError: "NSCocoaErrorDomain 134419", kind: .import) == nil)     // recovers by itself; we do not know more
        #expect(SyncStatusCopy.hint(forError: nil, kind: .setup) == nil)
    }
}
