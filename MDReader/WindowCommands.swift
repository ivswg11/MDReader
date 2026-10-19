import AppKit
import SwiftUI

/// File menu: ⌘N new window and ⌘T new tab (both open the start window), ⌘O open.
/// Replaces the document group's default "New", which would create an empty untitled file.
struct WindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                DocumentOpener.pendingTabParent = nil
                openWindow(id: StartView.windowID)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Tab") {
                DocumentOpener.pendingTabParent = NSApp.keyWindow
                openWindow(id: StartView.windowID)
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Open…") {
                NSDocumentController.shared.openDocument(nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}

extension StartView {
    static let windowID = "start"
}
