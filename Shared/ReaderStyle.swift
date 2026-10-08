import SwiftUI

/// Keys and defaults for values shared between the Settings window and document windows.
enum SettingsKey {
    static let horizontalMargin = "horizontalMargin"
    static let defaultHorizontalMargin: Double = 24
    static let textScale = "textScale"
    /// Body text size in points at 100% zoom. Headings and code scale with it.
    static let fontSize = "fontSize"
    static let defaultFontSize: Double = 13
    /// One of the `ReaderFont` designs, or an installed font family name.
    static let fontFamily = "fontFamily"
    /// Like `fontFamily`, for headings. Empty means "same as body".
    static let headingFontFamily = "headingFontFamily"
    /// A `ReaderTheme` raw value.
    static let theme = "theme"
    /// Base gap between blocks in points at 100% zoom. See `BlockSpacing` for how it's applied.
    static let spacing = "spacing"
}

/// Page colors. Each theme also fixes the window's light/dark appearance.
enum ReaderTheme: String, CaseIterable {
    case paper, dark

    static let `default` = ReaderTheme.dark

    /// `nil` means the standard system colors.
    var palette: ReaderPalette? {
        switch self {
        case .paper: .paper
        case .dark: nil
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .paper: .light
        case .dark: .dark
        }
    }
}

/// Code backgrounds, quote bars and secondary text are derived from `ink` through the
/// `.secondary` / `.quaternary` styles, so a palette only needs these colors.
struct ReaderPalette: Equatable {
    let background: Color
    let sidebar: Color
    let ink: Color

    /// Warm off-white paper with brown-black ink, like an old book page.
    static let paper = ReaderPalette(
        background: Color(red: 0.965, green: 0.937, blue: 0.867),
        sidebar: Color(red: 0.929, green: 0.894, blue: 0.808),
        ink: Color(red: 0.227, green: 0.192, blue: 0.153)
    )
}

/// The body font: one of the system designs, or any installed family by name.
enum ReaderFont {
    static let system = "system"
    static let serif = "serif"
    static let rounded = "rounded"

    static func font(_ family: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch family {
        case system: .system(size: size, weight: weight)
        case serif: .system(size: size, weight: weight, design: .serif)
        case rounded: .system(size: size, weight: weight, design: .rounded)
        default: .custom(family, size: size).weight(weight)
        }
    }
}

/// How the reader lays out text. The app builds it from Settings; Quick Look uses the defaults.
struct ReaderStyle: Equatable {
    /// Zoom on top of the font size, relative to the 13 pt the layout is designed at.
    var scale: Double = 1
    var horizontalMargin: Double = SettingsKey.defaultHorizontalMargin
    var spacing: Double = BlockSpacing.defaultBase
    var fontFamily: String = ReaderFont.system
    /// `nil` means headings use `fontFamily`.
    var headingFontFamily: String?
    var palette: ReaderPalette?
}
