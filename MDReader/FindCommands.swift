import SwiftUI

/// What the Find menu can do in the frontmost document window.
struct FindActions {
    let find: () -> Void
    let next: () -> Void
    let previous: () -> Void
    let hasMatches: Bool
}

extension FocusedValues {
    @Entry var findActions: FindActions?
}

/// Edit ▸ Find: ⌘F focuses the search field, ⌘G / ⇧⌘G step through matches.
struct FindCommands: Commands {
    @FocusedValue(\.findActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            Button("Find…") { actions?.find() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)
            Button("Find Next") { actions?.next() }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(actions?.hasMatches != true)
            Button("Find Previous") { actions?.previous() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(actions?.hasMatches != true)
        }
    }
}
