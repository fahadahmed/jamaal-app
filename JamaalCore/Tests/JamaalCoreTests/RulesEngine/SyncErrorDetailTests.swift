import Foundation
import Testing
@testable import JamaalCore

/// What a failed iCloud save is recorded as (#308): the item-level codes and which of OUR record types iCloud refused, never any
/// content, and what a tester is told about the common codes. A partial failure used to be just "CKErrorDomain 2".
struct SyncErrorDetailTests {

    private func partial(_ items: [(code: Int, message: String)]) -> NSError {
        var byItem: [AnyHashable: Error] = [:]
        for (i, item) in items.enumerated() {
            byItem["record-\(i)"] = NSError(domain: "CKErrorDomain", code: item.code, userInfo: [NSLocalizedDescriptionKey: item.message])
        }
        return NSError(domain: "CKErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to modify some records", "CKPartialErrors": byItem])
    }

    // MARK: Recording

    @Test func aPartialFailureNamesTheItemCodesAndTheRecordTypesRefused() {
        let e = partial([
            (12, "Cannot create new type CD_Habit in production schema"),
            (12, "Cannot create new type CD_Habit in production schema"),
            (15, "Cannot create new type CD_HabitEntry in production schema"),
        ])
        #expect(DiagnosticValue.detailedError(e).text == "CKErrorDomain 2 items=12x2,15x1 types=CD_Habit,CD_HabitEntry")
    }

    @Test func anErrorWithNoItemsIsJustItsDomainAndCode() {
        let e = NSError(domain: "CKErrorDomain", code: 9, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        #expect(DiagnosticValue.detailedError(e).text == "CKErrorDomain 9")
    }

    @Test func onlyOurOwnRecordTypeNamesEverGetThrough() {
        let e = partial([(12, "Record 'Draft the architecture review' CD_Secret failed"), (12, "Cannot create new type CD_Anchor")])
        let text = DiagnosticValue.detailedError(e).text
        #expect(text.contains("types=CD_Anchor"))
        #expect(!text.contains("Draft"), "a message can hold a title; it is dropped")
        #expect(!text.contains("CD_Secret"), "a name that is not one of the 14 is dropped")
    }

    @Test func aPartialFailureWithNoTypeNamesStillCountsItsItems() {
        let e = partial([(11, "Record not found"), (11, "Record not found")])
        #expect(DiagnosticValue.detailedError(e).text == "CKErrorDomain 2 items=11x2")
    }

    @Test func everyRecordTypeOfTheSchemaIsOnTheKnownList() {
        #expect(DiagnosticValue.knownRecordTypes.count == 14)
        #expect(DiagnosticValue.knownRecordTypes.contains("CD_TaskItem") && DiagnosticValue.knownRecordTypes.contains("CD_NudgeLog"))
    }

    // MARK: What a tester is told

    @Test(arguments: [
        ("CKErrorDomain 3", "No connection to iCloud right now. It will try again by itself."),
        ("CKErrorDomain 4", "No connection to iCloud right now. It will try again by itself."),
        ("CKErrorDomain 6", "iCloud is busy. It will try again by itself."),
        ("CKErrorDomain 23", "iCloud is busy. It will try again by itself."),
        ("CKErrorDomain 9", "Sign in to iCloud in Settings, and it will catch up."),
        ("CKErrorDomain 25", "Your iCloud storage is full, so changes can't be saved. Free some space and it will catch up."),
    ])
    func commonCodesGetAPlainLine(error: String, hint: String) {
        #expect(SyncStatusCopy.hint(forError: "Whatever (\(error))", kind: .export) == hint)
    }

    @Test func iCloudRefusingOurRecordsIsSaidToBeOnTheDevelopersSide() {
        let h = SyncStatusCopy.hint(forError: "Failed to modify some records (CKErrorDomain 2 items=12x3 types=CD_Habit)", kind: .export)
        #expect(h == "iCloud refused some changes. That is something on my side, not something you did. Please use Email support so I can fix it.")
    }

    @Test func aPlainPartialFailureAsksForARestartFirst() {
        let h = SyncStatusCopy.hint(forError: "Failed to modify some records (CKErrorDomain 2)", kind: .export)
        #expect(h == "iCloud took some changes and refused others. Closing and reopening Jamaal often clears it; if it stays, please use Email support.")
    }

    @Test func anUnknownErrorHasNoHint() {
        #expect(SyncStatusCopy.hint(forError: "Something odd (NSCocoaErrorDomain 4)", kind: .import) == nil)
        #expect(SyncStatusCopy.hint(forError: nil, kind: .export) == nil)
    }
}
