import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let markdownText = UTType(importedAs: "net.daringfireball.markdown")
}

/// A Markdown file. The app only writes it back when a task checkbox is clicked.
nonisolated struct MarkdownDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.markdownText, .plainText]

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
