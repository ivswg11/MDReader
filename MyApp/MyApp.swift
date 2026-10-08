import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        // An editing document group (not `viewing:`), so checkbox clicks can autosave back to the file.
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
                .defaultWindowFrame()
        }
        // Matches the shape defaultWindowFrame() sizes new windows to, so the first frame doesn't jump.
        .defaultSize(width: 1263, height: 877)
        .commands {
            WindowCommands()
            TextSizeCommands()
            FindCommands()
        }

        WindowGroup(id: StartView.windowID) {
            StartView()
                .defaultWindowFrame()
        }
        .defaultSize(width: 1263, height: 877)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
        }
    }
}
