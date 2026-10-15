//
//  SyncModeTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

/// When the store syncs through iCloud: only when the app is signed with its App Group (so it has the iCloud entitlement too).
/// Everything else (tests, previews, unsigned builds, CI, a store held in memory) stays local, as it always was.
struct SyncModeTests {

    @Test func aSignedAppWithItsGroupSyncs() {
        #expect(SyncMode.resolve(inMemory: false, hasGroup: true, disabled: false) == .cloudKit(container: "iCloud.dev.fhdamd.Jamaal"))
    }

    @Test func withoutTheGroupTheStoreStaysLocal() {
        #expect(SyncMode.resolve(inMemory: false, hasGroup: false, disabled: false) == .off, "unsigned builds, CI and the free team")
    }

    @Test func aStoreInMemoryNeverSyncs() {
        #expect(SyncMode.resolve(inMemory: true, hasGroup: true, disabled: false) == .off)
    }

    @Test func theDebugSwitchTurnsItOff() {
        #expect(SyncMode.resolve(inMemory: false, hasGroup: true, disabled: true) == .off)
    }

    @Test func theContainerNameMatchesTheEntitlement() throws {
        #expect(SyncMode.containerID == "iCloud.dev.fhdamd.Jamaal")
    }
}
