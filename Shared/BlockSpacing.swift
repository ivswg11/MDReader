import Foundation

/// Vertical gaps between blocks, all derived from one base value (the Spacing setting).
/// Related blocks sit closer than unrelated ones: list items are tight, paragraphs get the
/// base gap, and a heading gets more room above than below so it groups with what follows.
enum BlockSpacing {
    static let defaultBase: Double = 12

    /// The gap above `block`, as a multiple of the base value.
    static func ratio(before block: MarkdownBlock, after previous: MarkdownBlock?) -> Double {
        guard let previous else { return 0 }

        if case .heading(let level) = block.kind {
            // A heading right under another heading belongs with it, e.g. "## Next Week" then "### Ideas".
            if case .heading = previous.kind { return 0.75 }
            // Bigger headings start bigger sections, so they get more room above.
            return [2.5, 2, 1.5][safe: level - 1] ?? 1.25
        }
        if case .heading = previous.kind {
            return 0.5
        }

        switch (previous.kind, block.kind) {
        case (.listItem, .listItem):
            return 0.35
        case (.table, .table):
            return 0.2
        default:
            // Consecutive lines of the same quote read as one block.
            return previous.quoteDepth > 0 && block.quoteDepth > 0 ? 0.5 : 1
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
