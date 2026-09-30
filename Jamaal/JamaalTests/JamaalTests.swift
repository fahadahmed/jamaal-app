//
//  JamaalTests.swift
//  JamaalTests
//
//  Created by Fahad Ahmed on 25/9/2026.
//

import SwiftUI
import Testing
import JamaalCore
import ThreadsTokens
@testable import Jamaal

struct JamaalTests {

    /// Proves both packages are linked into the app: JamaalCore (local) and
    /// ThreadsKit (remote, 1.1.0 or later — `d1` only exists from 1.1.0).
    @Test func linksJamaalCoreAndThreadsKit() {
        #expect(!JamaalCore.version.isEmpty)
        _ = Color.Threads.d1
    }

}
