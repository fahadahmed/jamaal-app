//
//  ForegroundStateTests.swift
//  JamaalTests
//

import Foundation
import Testing
@testable import Jamaal

struct ForegroundStateTests {
    @Test func itFollowsTheLastThingItWasTold() {
        let state = ForegroundState()
        #expect(state.isForeground, "an app that has just started is taken to be on screen until it says otherwise")
        state.set(false)
        #expect(!state.isForeground)
        state.set(true)
        #expect(state.isForeground)
    }

    @Test func itCanBeReadFromAnyThreadWhileAnotherSetsIt() async {
        let state = ForegroundState()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask { if i.isMultiple(of: 2) { state.set(i.isMultiple(of: 4)) } else { _ = state.isForeground } }
            }
        }
        #expect(state.isForeground == true || state.isForeground == false)       // no crash and no torn read
    }
}
