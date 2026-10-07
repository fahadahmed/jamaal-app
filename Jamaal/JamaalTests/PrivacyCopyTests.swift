//
//  PrivacyCopyTests.swift
//  JamaalTests
//

import Foundation
import SwiftUI
import Testing
@testable import Jamaal

struct PrivacyCopyTests {

    @Test func theExportFileIsNamedForTheDay() {
        let utc = TimeZone(identifier: "UTC")!
        let day = Date(timeIntervalSince1970: 1_790_000_000)                            // 2026-09-21 in UTC
        #expect(PrivacyCopy.fileName(day, timeZone: utc) == "Jamaal-export-2026-09-21.json")
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        #expect(PrivacyCopy.fileName(Date(timeIntervalSince1970: 1_790_000_000 + 20 * 3600), timeZone: tokyo).hasSuffix(".json"))
    }

    @Test func theExportMessageCountsRecords() {
        #expect(PrivacyCopy.exported(records: 1) == "Exported 1 record. Choose where to keep the file.")
        #expect(PrivacyCopy.exported(records: 42) == "Exported 42 records. Choose where to keep the file.")
    }

    @Test func deletionAsksTwiceAndSaysItCannotBeUndone() {
        #expect(PrivacyCopy.firstTitle != PrivacyCopy.secondTitle)
        #expect(PrivacyCopy.secondMessage.contains("can't be undone"))
        #expect(PrivacyCopy.firstMessage.contains("export it first"))
    }

    @Test func theRecoveryCopyNamesTheDeviceAndPromisesTheCloudCopyIsSafe() {
        #expect(PrivacyCopy.recoveryTitle(device: "iPhone") == "Jamaal couldn't open its data on this iPhone.")
        #expect(PrivacyCopy.resetButton(device: "iPad") == "Reset this iPad's data")
        #expect(PrivacyCopy.recoveryBody(device: "iPhone").contains("reset this iPhone's copy"))
        #expect(PrivacyCopy.recoveryBody(device: "iPhone").contains("iCloud copy downloads again afterwards"))
        #expect(PrivacyCopy.resetFirstMessage(device: "iPad").contains("on this iPad") && PrivacyCopy.resetFirstMessage(device: "iPad").contains("iCloud copy downloads again"))
        #expect(PrivacyCopy.recoveryStillFailing(device: "Mac").contains("this Mac's copy"))
    }

    @Test func themesFollowTheSystemUnlessChosen() {
        #expect(AppTheme.system.scheme == nil && AppTheme.light.scheme == .light && AppTheme.dark.scheme == .dark)
        #expect(AppTheme.allCases.map(\.title) == ["System", "Light", "Dark"])
        #expect(AppTheme(rawValue: "nonsense") == nil)
    }
}
