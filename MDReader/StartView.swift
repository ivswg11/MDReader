import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The window ⌘N and ⌘T open: an Open button, a drop zone and the 10 most recent files.
/// Picking a file opens it in this window's place (same tab, same frame).
struct StartView: View {
    @AppStorage(SettingsKey.theme) private var theme = ReaderTheme.default

    @State private var window: NSWindow?
    @State private var recents: [URL] = []
    @State private var isDropTargeted = false

    private var palette: ReaderPalette? { theme.palette }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Drop a Markdown file here")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Open File…", action: showOpenPanel)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("o", modifiers: .command)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35))
                    .background(
                        Color.accentColor.opacity(isDropTargeted ? 0.08 : 0),
                        in: .rect(cornerRadius: 14)
                    )
            }
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)

            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                    VStack(spacing: 0) {
                        ForEach(recents, id: \.self) { url in
                            RecentRow(url: url) { open(url) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 520)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(palette?.ink ?? .primary)
        .background(palette?.background ?? .clear)
        .preferredColorScheme(theme.colorScheme)
        .navigationTitle("Open")
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: Self.isMarkdown) ?? urls.first else { return false }
            open(url)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .background(WindowReader { window = $0 })
        .onAppear {
            recents = Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
        }
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdownText, .plainText]
        panel.allowsMultipleSelection = false
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            open(url)
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(panel.runModal())
        }
    }

    private func open(_ url: URL) {
        DocumentOpener.open(url, replacing: window)
    }

    private static func isMarkdown(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .markdownText) == true
    }
}

private struct RecentRow: View {
    let url: URL
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                    Text(url.deletingLastPathComponent().path(percentEncoded: false).abbreviatingHome)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(.rect)
            .background(.quaternary.opacity(isHovering ? 0.6 : 0), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private extension String {
    /// `/Users/ivan/Documents` → `~/Documents`.
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}

/// Opens Markdown files as documents, optionally taking over a start window's place.
enum DocumentOpener {
    /// Set by ⌘T: the window the next start window should join as a tab.
    static var pendingTabParent: NSWindow?

    static func open(_ url: URL, replacing startWindow: NSWindow?) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { document, wasAlreadyOpen, _ in
            MainActor.assumeIsolated {
                guard let document else { return }
                withDocumentWindow(of: document) { documentWindow in
                    // A file that's already open just comes forward; otherwise it takes the start window's tab.
                    if let startWindow, startWindow !== documentWindow {
                        if !wasAlreadyOpen {
                            startWindow.addTabbedWindow(documentWindow, ordered: .above)
                        }
                        documentWindow.makeKeyAndOrderFront(nil)
                        startWindow.close()
                    } else {
                        documentWindow.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
    }

    /// SwiftUI creates a document's window a moment after the document opens, so check a few times.
    private static func withDocumentWindow(of document: NSDocument, attempt: Int = 0, _ body: @escaping (NSWindow) -> Void) {
        if let window = document.windowControllers.first?.window {
            body(window)
        } else if attempt < 20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withDocumentWindow(of: document, attempt: attempt + 1, body)
            }
        }
    }
}

/// Reports the hosting window once the view is in one, and adds it as a tab if ⌘T asked for that.
private struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if let parent = DocumentOpener.pendingTabParent, parent !== window {
                DocumentOpener.pendingTabParent = nil
                parent.addTabbedWindow(window, ordered: .above)
                window.makeKeyAndOrderFront(nil)
            }
            onWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
