//
//  ExportFile.swift
//  Jamaal
//

import SwiftUI
import UniformTypeIdentifiers

/// The export as a document, so the Mac's save panel can write it (the iOS share sheet takes a file URL instead).
struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
