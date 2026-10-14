//
//  AppGroupTests.swift
//  JamaalCoreTests
//

import Foundation
import Testing
@testable import JamaalCore

/// Where the store lives: inside the App Group container when there is one (so widgets read the same data), and
/// where it always has been when there isn't (the free team, tests, previews).
struct AppGroupTests {

    private let fallback = URL(fileURLWithPath: "/tmp/fallback/default.store")

    @Test func withoutAGroupTheStoreStaysWhereItWas() {
        #expect(StoreLocation.url(groupContainer: nil, defaultURL: fallback) == fallback)
    }

    @Test func withAGroupTheStoreLivesInsideItsContainer() {
        let group = URL(fileURLWithPath: "/tmp/group", isDirectory: true)
        let url = StoreLocation.url(groupContainer: group, defaultURL: fallback)
        #expect(url.path == "/tmp/group/Library/Application Support/Jamaal.store")
    }

    @Test func preparingCreatesTheFolderTheStoreSitsIn() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("JamaalStoreTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = StoreLocation.url(groupContainer: root, defaultURL: fallback)
        try StoreLocation.prepare(url)
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        try StoreLocation.prepare(url)                                     // already there: fine
    }

    @Test func theIdentifierComesFromTheBuildSetting() {
        #expect(AppGroup.identifier(fromInfo: "group.dev.fhdamd.Jamaal") == "group.dev.fhdamd.Jamaal")
        #expect(AppGroup.identifier(fromInfo: "ABCDE12345.dev.fhdamd.Jamaal") == "ABCDE12345.dev.fhdamd.Jamaal")
    }

    @Test(arguments: [nil, "", "  ", "$(APP_GROUP_ID)", "$(TeamIdentifierPrefix)dev.fhdamd.Jamaal"] as [String?])
    func aMissingOrUnexpandedIdentifierMeansNoGroup(_ value: String?) {
        #expect(AppGroup.identifier(fromInfo: value) == nil)
    }

    @Test func noGroupMeansTheStandardDefaults() {
        #expect(AppGroup.defaults(identifier: nil, containerAvailable: false) === UserDefaults.standard)
        #expect(AppGroup.defaults(identifier: "group.x", containerAvailable: false) === UserDefaults.standard,
                "an identifier the app isn't entitled to is no group")
    }
}
