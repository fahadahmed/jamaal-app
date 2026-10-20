import Foundation
import Testing
@testable import JamaalCore

/// What the iCloud sync screen can tell you: when this device last received and sent, what went wrong last, and one calm line
/// for it all. Pure, so it is tested here; the app only feeds it CloudKit's events.
struct SyncStatusTests {

    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private func ago(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }

    // MARK: Recording events

    @Test func aFinishedImportAndExportAreRemembered() {
        var a = SyncActivity()
        a.record(.import, endedAt: ago(120), succeeded: true, error: nil)
        a.record(.export, endedAt: ago(60), succeeded: true, error: nil)
        #expect(a.lastImportAt == ago(120))
        #expect(a.lastExportAt == ago(60))
        #expect(a.lastError == nil)
    }

    @Test func anEventStillInProgressChangesNothing() {
        var a = SyncActivity()
        a.record(.import, endedAt: nil, succeeded: false, error: nil)
        #expect(a == SyncActivity())
    }

    @Test func aFailureIsKeptWithItsKindAndTime() {
        var a = SyncActivity()
        a.record(.import, endedAt: ago(30), succeeded: false, error: "Network unavailable")
        #expect(a.lastError == "Network unavailable")
        #expect(a.lastErrorKind == .import)
        #expect(a.lastErrorAt == ago(30))
        #expect(a.lastImportAt == nil, "a failed import is not a received one")
    }

    @Test func aLaterSuccessOfTheSameKindClearsTheProblem() {
        var a = SyncActivity()
        a.record(.import, endedAt: ago(100), succeeded: false, error: "Network unavailable")
        a.record(.import, endedAt: ago(10), succeeded: true, error: nil)
        #expect(a.lastError == nil)
        #expect(a.lastImportAt == ago(10))
    }

    @Test func aSuccessOfAnotherKindDoesNotHideAProblem() {
        var a = SyncActivity()
        a.record(.import, endedAt: ago(100), succeeded: false, error: "Zone not found")
        a.record(.export, endedAt: ago(10), succeeded: true, error: nil)
        #expect(a.lastError == "Zone not found")
    }

    @Test func aFailureWithNoTextStillSaysSomethingWentWrong() {
        var a = SyncActivity()
        a.record(.export, endedAt: ago(5), succeeded: false, error: nil)
        #expect(a.lastError == "It didn't say why.")
    }

    @Test func theActivitySurvivesBeingSavedAndLoaded() throws {
        var a = SyncActivity()
        a.record(.import, endedAt: ago(5), succeeded: true, error: nil)
        let back = try JSONDecoder().decode(SyncActivity.self, from: JSONEncoder().encode(a))
        #expect(back == a)
    }

    // MARK: The one calm line

    @Test func offOnThisDeviceSaysItKeepsItsOwnCopy() {
        let line = SyncStatusCopy.headline(isOn: false, account: .available, activity: SyncActivity(), now: now)
        #expect(line == "Off on this device. It keeps its own copy.")
    }

    @Test func noICloudAccountSaysHowToFixIt() {
        #expect(SyncStatusCopy.headline(isOn: true, account: .noAccount, activity: SyncActivity(), now: now)
                == "Sign in to iCloud in Settings to sync.")
        #expect(SyncStatusCopy.headline(isOn: true, account: .restricted, activity: SyncActivity(), now: now)
                == "iCloud is restricted on this device.")
    }

    @Test func beforeAnythingHasHappenItIsWaiting() {
        #expect(SyncStatusCopy.headline(isOn: true, account: .available, activity: SyncActivity(), now: now)
                == "Waiting for the first sync.")
    }

    @Test func afterASuccessItIsSyncingNormally() {
        var a = SyncActivity(); a.record(.import, endedAt: ago(30), succeeded: true, error: nil)
        #expect(SyncStatusCopy.headline(isOn: true, account: .available, activity: a, now: now) == "Syncing normally.")
    }

    @Test func aProblemNewerThanTheLastSuccessIsSaid() {
        var a = SyncActivity()
        a.record(.import, endedAt: ago(300), succeeded: true, error: nil)
        a.record(.export, endedAt: ago(30), succeeded: false, error: "Quota exceeded")
        #expect(SyncStatusCopy.headline(isOn: true, account: .available, activity: a, now: now) == "The last attempt didn't go through.")
    }

    @Test func aProblemOlderThanASuccessOfAnotherKindIsStillShownButNotTheHeadline() {
        var a = SyncActivity()
        a.record(.export, endedAt: ago(500), succeeded: false, error: "Quota exceeded")
        a.record(.import, endedAt: ago(30), succeeded: true, error: nil)
        #expect(SyncStatusCopy.headline(isOn: true, account: .available, activity: a, now: now) == "Syncing normally.")
        #expect(a.lastError == "Quota exceeded")
    }

    // MARK: When

    @Test(arguments: [
        (10.0, "just now"), (59.0, "just now"), (60.0, "1 min ago"), (600.0, "10 min ago"),
        (3_600.0, "1 h ago"), (7_300.0, "2 h ago"), (86_400.0, "1 day ago"), (3 * 86_400.0, "3 days ago"),
    ])
    func whenIsPlainAndRelative(seconds: Double, expected: String) {
        #expect(SyncStatusCopy.when(ago(seconds), now: now) == expected)
    }

    @Test func noTimeIsNotYet() {
        #expect(SyncStatusCopy.when(nil, now: now) == "Not yet")
    }

    // MARK: Copy details

    @Test func theDetailsAreOnePlainTextBlockToPaste() {
        var a = SyncActivity()
        a.record(.import, endedAt: ago(120), succeeded: true, error: nil)
        a.record(.export, endedAt: ago(30), succeeded: false, error: "Quota exceeded")
        let text = SyncStatusCopy.details(isOn: true, account: .available, activity: a, container: "iCloud.test", device: "iPad", now: now)
        #expect(text.contains("Device: iPad"))
        #expect(text.contains("Container: iCloud.test"))
        #expect(text.contains("Sync: on"))
        #expect(text.contains("iCloud account: signed in"))
        #expect(text.contains("Last received: 2 min ago"))
        #expect(text.contains("Last sent: Not yet"))
        #expect(text.contains("Last problem: Quota exceeded (sending, just now)"))
    }
}
