//
//  Aliases.swift
//  Jamaal
//

import JamaalCore

/// SwiftUI has its own `Anchor`, so any file that imports both SwiftUI and JamaalCore sees the name as
/// ambiguous (and `JamaalCore.Anchor` doesn't resolve, since the package also has a type named `JamaalCore`).
/// This file imports only JamaalCore, so the name is unambiguous here; views use the alias.
typealias AnchorInstance = Anchor
