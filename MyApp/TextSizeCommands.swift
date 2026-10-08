import SwiftUI

/// View menu items for scaling document text: ⌘+ bigger, ⌘- smaller, ⌘0 actual size.
struct TextSizeCommands: Commands {
    @AppStorage(SettingsKey.textScale) private var textScale = 1.0

    /// Fixed steps, like Safari's zoom levels, so repeated presses land on round numbers.
    private static let steps: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Make Text Bigger") {
                textScale = Self.steps.first { $0 > textScale + 0.001 } ?? textScale
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(textScale >= Self.steps.last!)

            Button("Make Text Smaller") {
                textScale = Self.steps.last { $0 < textScale - 0.001 } ?? textScale
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(textScale <= Self.steps.first!)

            Button("Actual Size") {
                textScale = 1
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(textScale == 1)

            Divider()
        }
    }
}
