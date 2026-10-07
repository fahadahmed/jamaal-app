import Foundation
import Testing
@testable import JamaalCore

/// The note editor's formatting rules (TK-04). Selections are character offsets.
struct NoteEditingTests {

    private func edit(_ text: String, _ r: Range<Int>) -> (String, Range<Int>) { (text, r) }
    private func sel(_ e: NoteEdit) -> String { let c = Array(e.text); return String(c[e.selection]) }

    // MARK: Checklist

    @Test func aPlainLineBecomesAChecklistItemAndTheCaretStaysAtItsEnd() {
        let e = NoteEditing.toggleChecklist("Ask about the letter", selection: 20..<20)
        #expect(e.text == "- [ ] Ask about the letter" && e.selection == 26..<26)
    }

    @Test func aChecklistItemTurnsBackIntoAPlainLine() {
        #expect(NoteEditing.toggleChecklist("- [ ] Ask", selection: 5..<5).text == "Ask")
        #expect(NoteEditing.toggleChecklist("- [x] Done thing", selection: 0..<0).text == "Done thing")
        #expect(NoteEditing.toggleChecklist("* [X] Done thing", selection: 0..<0).text == "Done thing")
    }

    @Test func aBulletBecomesAChecklistItem() {
        #expect(NoteEditing.toggleChecklist("- Buy milk", selection: 0..<0).text == "- [ ] Buy milk")
        #expect(NoteEditing.toggleChecklist("* Buy milk", selection: 0..<0).text == "- [ ] Buy milk")
    }

    @Test func severalSelectedLinesAreAllToggledTogether() {
        let text = "one\ntwo\nthree"
        let on = NoteEditing.toggleChecklist(text, selection: 2..<10)
        #expect(on.text == "- [ ] one\n- [ ] two\n- [ ] three")
        #expect(NoteEditing.toggleChecklist(on.text, selection: 0..<on.text.count).text == text)
    }

    @Test func aMixedSelectionMakesEveryLineAChecklistItemWithoutDoublingTheOnesThatAre() {
        let e = NoteEditing.toggleChecklist("- [ ] a\nb", selection: 0..<9)
        #expect(e.text == "- [ ] a\n- [ ] b")
    }

    @Test func onlyTheLinesTouchedChangeAndTheRestStaysAsItWas() {
        let e = NoteEditing.toggleChecklist("first\nsecond\nthird", selection: 7..<7)
        #expect(e.text == "first\n- [ ] second\nthird")
    }

    @Test func aSelectionThatEndsAtTheStartOfTheNextLineLeavesThatLineAlone() {
        let e = NoteEditing.toggleChecklist("one\ntwo", selection: 0..<4)                     // the newline is selected, the next line isn't
        #expect(e.text == "- [ ] one\ntwo")
    }

    @Test func anEmptyBoxCountsAsAChecklistItemSoItTurnsBack() {
        #expect(NoteEditing.toggleChecklist("- [ ]", selection: 0..<0).text == "")
    }

    @Test func anEmptyNoteGetsAFirstItem() {
        let e = NoteEditing.toggleChecklist("", selection: 0..<0)
        #expect(e.text == "- [ ] " && e.selection == 6..<6)
    }

    // MARK: Wrapping

    @Test func aSelectionIsWrappedAndStaysSelected() {
        let e = NoteEditing.bold("see the letter now", selection: 8..<14)
        #expect(e.text == "see the **letter** now" && sel(e) == "letter")
        #expect(sel(NoteEditing.italic("see the letter now", selection: 8..<14)) == "letter")
        #expect(NoteEditing.code("ref RX-2291", selection: 4..<11).text == "ref `RX-2291`")
    }

    @Test func wrappingASelectionAlreadyWrappedUnwrapsIt() {
        let e = NoteEditing.bold("see the **letter** now", selection: 10..<16)
        #expect(e.text == "see the letter now" && sel(e) == "letter")
        #expect(NoteEditing.italic("a *b* c", selection: 3..<4).text == "a b c")
        #expect(NoteEditing.code("a `b` c", selection: 3..<4).text == "a b c")
    }

    @Test func italicInsideBoldWrapsInsteadOfStrippingTheBold() {
        let e = NoteEditing.italic("a **b** c", selection: 4..<5)
        #expect(e.text == "a ***b*** c")                                             // bold plus italic, not stripped
    }

    @Test func withNothingSelectedTheMarkersGoInAndTheCaretSitsBetween() {
        let e = NoteEditing.bold("hello ", selection: 6..<6)
        #expect(e.text == "hello ****" && e.selection == 8..<8)
        let again = NoteEditing.bold(e.text, selection: 8..<8)                         // tapping again takes the empty pair back out
        #expect(again.text == "hello " && again.selection == 6..<6)
    }

    @Test func aSelectionOutsideTheTextIsKeptInsideIt() {
        let e = NoteEditing.bold("abc", selection: 1..<99)
        #expect(e.text == "a**bc**")
        #expect(NoteEditing.bold("", selection: 5..<9).text == "****")
    }

    // MARK: Link

    @Test func aLinkWrapsTheSelectionAndSelectsTheAddressToBeTypedOver() {
        let e = NoteEditing.link("see booking page today", selection: 4..<16)
        #expect(e.text == "see [booking page](https://) today" && sel(e) == "https://")
    }

    @Test func aLinkWithNothingSelectedStartsWithAWordToReplace() {
        let e = NoteEditing.link("", selection: 0..<0)
        #expect(e.text == "[link](https://)" && sel(e) == "https://")
    }

    // MARK: Return continues a list

    @Test func returnAfterAChecklistItemStartsTheNextItem() {
        let old = "- [ ] Ask"
        let new = "- [ ] Ask\n"
        let e = NoteEditing.continuation(old: old, new: new, caret: 10)
        #expect(e?.text == "- [ ] Ask\n- [ ] " && e?.selection == 16..<16)
    }

    @Test func returnInTheMiddleOfAnItemCarriesTheRestToTheNextItem() {
        let old = "- [ ] AskNow"
        let new = "- [ ] Ask\nNow"
        let e = NoteEditing.continuation(old: old, new: new, caret: 10)
        #expect(e?.text == "- [ ] Ask\n- [ ] Now")
    }

    @Test func returnOnAnEmptyItemEndsTheList() {
        let old = "- [ ] Ask\n- [ ] "
        let new = "- [ ] Ask\n- [ ] \n"
        let e = NoteEditing.continuation(old: old, new: new, caret: 17)
        #expect(e?.text == "- [ ] Ask\n" && e?.selection == 10..<10)
    }

    @Test func aBulletListContinuesToo() {
        let e = NoteEditing.continuation(old: "- Milk", new: "- Milk\n", caret: 7)
        #expect(e?.text == "- Milk\n- ")
        #expect(NoteEditing.continuation(old: "- ", new: "- \n", caret: 3)?.text == "")
    }

    @Test func aReplacementThatHappensToAddACharacterIsNotAReturn() {
        // Same length as one inserted newline, but the rest of the text changed too.
        #expect(NoteEditing.continuation(old: "- [ ] A", new: "- [ ] X\n", caret: 8) == nil)
    }

    @Test func returnOnAPlainLineIsLeftAlone() {
        #expect(NoteEditing.continuation(old: "Hello", new: "Hello\n", caret: 6) == nil)
    }

    @Test func onlyASingleTypedNewlineCountsNotAPasteOrADeletion() {
        #expect(NoteEditing.continuation(old: "- [ ] A", new: "- [ ] A\n\n", caret: 9) == nil)           // two characters
        #expect(NoteEditing.continuation(old: "- [ ] A\nB", new: "- [ ] A", caret: 7) == nil)             // a deletion
        #expect(NoteEditing.continuation(old: "- [ ] A", new: "- [ ] AB", caret: 8) == nil)               // not a newline
        #expect(NoteEditing.continuation(old: "- [ ] A", new: "- [ ] A\n", caret: 3) == nil)              // caret not after the newline
    }

    @Test func theNoteStillParsesAsTheDetailExpectsAfterEditing() {
        let e = NoteEditing.toggleChecklist("Ask about **letters**\nCall", selection: 0..<26)
        #expect(TaskNotes.items(e.text).count == 2)
        #expect(TaskNotes.progress(e.text) == TaskNoteProgress(done: 0, total: 2))
        let ticked = TaskNotes.toggled(e.text, line: 0)
        #expect(TaskNotes.progress(ticked) == TaskNoteProgress(done: 1, total: 2))
    }
}
