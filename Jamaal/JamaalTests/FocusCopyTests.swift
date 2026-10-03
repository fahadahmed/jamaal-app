//
//  FocusCopyTests.swift
//  JamaalTests
//

import Testing
import JamaalCore
@testable import Jamaal

/// The chip's, the focus screen's and the finish sheet's words. A timer is a fact, never a verdict.
struct FocusCopyTests {

    @Test(arguments: [(0, "0:00"), (5, "0:05"), (65, "1:05"), (1450, "24:10"), (3599, "59:59"), (3600, "1:00:00"), (8052, "2:14:12")])
    func theClockCountsUpInMinutesAndSeconds(seconds: Int, text: String) {
        #expect(FocusCopy.clock(seconds) == text)
    }

    @Test func negativeSecondsReadAsZero() {
        #expect(FocusCopy.clock(-5) == "0:00")
    }

    @Test func theEstimateIsNamedPlainly() {
        #expect(FocusCopy.ofEstimate(60) == "of 60 min")
        #expect(FocusCopy.ofEstimate(nil) == nil)
    }

    @Test func theFinishSheetReadsActualAgainstEstimate() {
        #expect(FocusCopy.actualVersusEstimate(seconds: 74 * 60, estimate: 60) == "74 min · estimated 60")
        #expect(FocusCopy.actualVersusEstimate(seconds: 74 * 60, estimate: nil) == "74 min")
        #expect(FocusCopy.actualVersusEstimate(seconds: 20, estimate: 30) == "1 min · estimated 30")      // never "0 min"
        #expect(FocusCopy.actualVersusEstimate(seconds: 0, estimate: 30) == "0 min · estimated 30")
    }

    @Test func stopForNowSaysWhatItKeeps() {
        #expect(FocusCopy.stopForNowNote(seconds: 74 * 60) == "Stop for now keeps the 74 min and leaves the task on today.")
    }

    @Test func theChipsAnchorLineIsOneCalmSentence() {
        #expect(FocusCopy.edgeLine(ApproachingEdge(title: "Asr", minutes: 10, kind: .closing)) == "Asr closes in 10 min")
        #expect(FocusCopy.edgeLine(ApproachingEdge(title: "Maghrib", minutes: 12, kind: .opening)) == "Maghrib in 12 min")
        #expect(FocusCopy.edgeLine(ApproachingEdge(title: "Asr", minutes: 1, kind: .closing)) == "Asr closes in 1 min")
    }

    @Test func rowsShowTimingWhileLiveAndTheTotalOnceDone() {
        #expect(FocusCopy.timingMeta(trackedSeconds: 24 * 60, isLive: true) == "Timing · 24 min")
        #expect(FocusCopy.timingMeta(trackedSeconds: 0, isLive: true) == "Timing")
        #expect(FocusCopy.timingMeta(trackedSeconds: 74 * 60, isLive: false) == "74 min")
        #expect(FocusCopy.timingMeta(trackedSeconds: 0, isLive: false) == nil)
        #expect(FocusCopy.timingMeta(trackedSeconds: 20, isLive: false) == nil)             // under a minute isn't worth a figure
    }

    @Test func settleSheetWordsMatchTheKindOfSession() {
        #expect(FocusCopy.settleEyebrow(minutes: 24) == "Timing now · 24 min")
        #expect(FocusCopy.settleLine == "Settle this one first. Its time is kept whichever you pick.")
        #expect(FocusCopy.thenBegin("Call the clinic back") == "Then Begin \"Call the clinic back\"")
    }

    @Test func toastsAndPauseAreNamedPlainly() {
        #expect(FocusCopy.doneToast("Draft the architecture review") == "Done · Draft the architecture review")
        #expect(FocusCopy.pauseTitle(isPaused: false) == "Pause")
        #expect(FocusCopy.pauseTitle(isPaused: true) == "Resume")
    }
}
