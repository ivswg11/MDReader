import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.theme) private var theme = ReaderTheme.default
    @AppStorage(SettingsKey.horizontalMargin) private var horizontalMargin = SettingsKey.defaultHorizontalMargin
    @AppStorage(SettingsKey.spacing) private var spacing = BlockSpacing.defaultBase
    @AppStorage(SettingsKey.fontFamily) private var fontFamily = ReaderFont.system
    @AppStorage(SettingsKey.headingFontFamily) private var headingFontFamily = ""
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsKey.defaultFontSize

    private let installedFamilies = NSFontManager.shared.availableFontFamilies

    private var isDefault: Bool {
        theme == .default
            && horizontalMargin == SettingsKey.defaultHorizontalMargin
            && spacing == BlockSpacing.defaultBase
            && fontFamily == ReaderFont.system
            && headingFontFamily.isEmpty
            && fontSize == SettingsKey.defaultFontSize
    }

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $theme) {
                    Text("Paper").tag(ReaderTheme.paper)
                    Text("Dark").tag(ReaderTheme.dark)
                }
                .pickerStyle(.segmented)
            }

            Section {
                SliderRow(title: "Side margin", value: $horizontalMargin, range: 0...160, step: 4)
                SliderRow(title: "Spacing", value: $spacing, range: 4...32, step: 1)
            } header: {
                Text("Layout")
            } footer: {
                Text("Spacing is the gap between paragraphs. Lists are tighter, sections looser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Text") {
                Picker("Body font", selection: $fontFamily) {
                    fontOptions
                }
                Picker("Heading font", selection: $headingFontFamily) {
                    Text("Same as Body").tag("")
                    Divider()
                    fontOptions
                }
                LabeledContent("Font size") {
                    Stepper(value: $fontSize, in: 9...32, step: 1) {
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                    }
                }
            }

            Section("Preview") {
                VStack(alignment: .leading, spacing: spacing * 0.5) {
                    Text("Chapter One")
                        .font(ReaderFont.font(
                            headingFontFamily.isEmpty ? fontFamily : headingFontFamily,
                            size: fontSize * 22 / SettingsKey.defaultFontSize,
                            weight: .bold
                        ))
                    Text("The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs.")
                        .font(ReaderFont.font(fontFamily, size: fontSize))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(theme.palette?.ink ?? .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(theme.palette?.background ?? Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 8))
                .environment(\.colorScheme, theme.colorScheme)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    theme = .default
                    horizontalMargin = SettingsKey.defaultHorizontalMargin
                    spacing = BlockSpacing.defaultBase
                    fontFamily = ReaderFont.system
                    headingFontFamily = ""
                    fontSize = SettingsKey.defaultFontSize
                }
                .disabled(isDefault)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var fontOptions: some View {
        Text("System").tag(ReaderFont.system)
        Text("Serif (New York)").tag(ReaderFont.serif)
        Text("Rounded").tag(ReaderFont.rounded)
        Divider()
        ForEach(installedFamilies, id: \.self) { family in
            Text(family).tag(family)
        }
    }
}

/// A labeled slider with its value on the right, so every slider row lines up the same way.
private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                Slider(value: $value, in: range, step: step)
                    .frame(width: 180)
                Text("\(Int(value)) pt")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        } label: {
            Text(title)
        }
    }
}

#Preview {
    SettingsView()
}
