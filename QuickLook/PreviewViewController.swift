import AppKit
import QuickLookUI
import SwiftUI

/// Finder's Quick Look (Space bar) preview for Markdown files, using the app's reader view.
final class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        view = NSView()
        preferredContentSize = NSSize(width: 820, height: 640)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let data = try Data(contentsOf: url)
        let blocks = MarkdownParser.blocks(from: String(decoding: data, as: UTF8.self))

        let host = NSHostingView(rootView: QuickLookReader(blocks: blocks))
        host.frame = view.bounds
        host.autoresizingMask = [.width, .height]
        view.addSubview(host)
    }
}

private struct QuickLookReader: View {
    let blocks: [MarkdownBlock]

    var body: some View {
        MarkdownReaderView(blocks: blocks)
    }
}
