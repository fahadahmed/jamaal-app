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
    /// ThreadsKit (remote, 2.0.0 or later: the palette protocol, fonts and type roles).
    @Test func linksJamaalCoreAndThreadsKit() {
        #expect(!JamaalCore.version.isEmpty)
        _ = JamaalPalette().d1
        #expect(ThreadsType.spec(for: .body).fontName == "HankenGrotesk-Regular")
    }

    /// The bundled fonts register and resolve in the running app.
    @Test func theBundledFontsRegister() {
        #expect(ThreadsFonts.registerAll().isEmpty)
    }

    /// `TaskCategory.colorKey` values (JamaalCore) and the category colours (ThreadsKit) are two lists
    /// that have to agree: every key a category can store has a colour.
    @Test func everyCategoryColourKeyHasAThreadsKitColour() {
        let stored = Set(CategoryColor.allCases.filter { !$0.isUnknown }.map(\.rawValue))
        let drawn = Set(JamaalPalette.categories.map(\.key))
        #expect(stored == drawn)
    }
}
