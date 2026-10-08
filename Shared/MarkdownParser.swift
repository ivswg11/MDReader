import Foundation

/// One rendered block of a Markdown document: a heading, paragraph, list item, and so on.
struct MarkdownBlock: Identifiable {
    enum Kind: Equatable {
        case heading(level: Int)
        case paragraph
        case listItem(marker: String, depth: Int)
        case code
        case table
        case rule
    }

    /// A `- [ ]` / `- [x]` list item. `index` counts task items in document order, which is
    /// how `TaskListSource` finds the matching line in the file.
    struct Task: Equatable {
        let index: Int
        let isChecked: Bool
    }

    let id: Int
    let kind: Kind
    let quoteDepth: Int
    var text: AttributedString
    var task: Task?
}

/// Splits Foundation's Markdown parse into blocks, using each run's `presentationIntent`.
/// Inline styling (bold, italic, code, links) stays on the `AttributedString` for `Text` to render.
enum MarkdownParser {
    static func blocks(from source: String) -> [MarkdownBlock] {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: source, options: options) else {
            return [MarkdownBlock(id: 0, kind: .paragraph, quoteDepth: 0, text: AttributedString(source))]
        }

        var blocks: [MarkdownBlock] = []
        var lastGroup: Int?
        var lastCell: Int?

        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let slice = AttributedString(parsed[run.range])

            // Table cells are grouped by row, so a whole row renders on one line.
            let cell = components.first { if case .tableCell = $0.kind { true } else { false } }
            let row = components.first {
                switch $0.kind {
                case .tableRow, .tableHeaderRow: true
                default: false
                }
            }
            let group = (cell != nil ? row?.identity : components.first?.identity)

            if let group, group == lastGroup, !blocks.isEmpty {
                if let cell, cell.identity != lastCell {
                    blocks[blocks.count - 1].text.append(AttributedString("   │   "))
                }
                blocks[blocks.count - 1].text.append(slice)
            } else {
                blocks.append(MarkdownBlock(
                    id: blocks.count,
                    kind: kind(for: components),
                    quoteDepth: components.count { $0.kind == .blockQuote },
                    text: slice
                ))
            }
            lastGroup = group
            lastCell = cell?.identity
        }

        for index in blocks.indices where blocks[index].kind == .code {
            trimTrailingNewlines(&blocks[index].text)
        }
        markTasks(in: &blocks)
        return blocks
    }

    /// `components` runs innermost to outermost.
    private static func kind(for components: [PresentationIntent.IntentType]) -> MarkdownBlock.Kind {
        var ordinal: Int?
        for component in components {
            switch component.kind {
            case .header(let level):
                return .heading(level: level)
            case .codeBlock:
                return .code
            case .thematicBreak:
                return .rule
            case .tableCell, .tableRow, .tableHeaderRow, .table:
                return .table
            case .listItem(let itemOrdinal):
                if ordinal == nil { ordinal = itemOrdinal }
            case .orderedList, .unorderedList:
                // Only the innermost list item gets a marker; text after its first paragraph is indented without one.
                guard let itemOrdinal = ordinal, isFirstParagraph(components) else {
                    return .listItem(marker: "", depth: listDepth(components))
                }
                let marker = component.kind == .orderedList ? "\(itemOrdinal)." : "•"
                return .listItem(marker: marker, depth: listDepth(components))
            default:
                continue
            }
        }
        return .paragraph
    }

    private static func listDepth(_ components: [PresentationIntent.IntentType]) -> Int {
        components.count { $0.kind == .orderedList || $0.kind == .unorderedList }
    }

    /// Ordinal-1 paragraphs are the first in their list item. Later paragraphs share the item's ordinal
    /// but have a different paragraph identity; we detect them by the paragraph not being the item's first child.
    private static func isFirstParagraph(_ components: [PresentationIntent.IntentType]) -> Bool {
        guard let itemIndex = components.firstIndex(where: {
            if case .listItem = $0.kind { true } else { false }
        }), itemIndex > 0 else { return true }
        // Foundation assigns identities in document order, so the first child of an item is item identity + 1.
        return components[itemIndex - 1].identity == components[itemIndex].identity + 1
    }

    /// Turns list items starting with `[ ]` or `[x]` into tasks and strips the marker from the text.
    /// Only an item's first paragraph (the one with a bullet) can start a task.
    private static func markTasks(in blocks: inout [MarkdownBlock]) {
        var taskIndex = 0
        for index in blocks.indices {
            guard case .listItem(let marker, _) = blocks[index].kind, !marker.isEmpty else { continue }
            let characters = blocks[index].text.characters
            let prefix = String(characters.prefix(3))
            guard prefix == "[ ]" || prefix.lowercased() == "[x]" else { continue }
            let afterPrefix = characters.index(characters.startIndex, offsetBy: 3)
            guard afterPrefix == characters.endIndex || characters[afterPrefix].isWhitespace else { continue }

            let markerEnd = afterPrefix == characters.endIndex ? afterPrefix : characters.index(after: afterPrefix)
            blocks[index].text.removeSubrange(blocks[index].text.startIndex..<markerEnd)
            blocks[index].task = .init(index: taskIndex, isChecked: prefix != "[ ]")
            taskIndex += 1
        }
    }

    private static func trimTrailingNewlines(_ text: inout AttributedString) {
        while let last = text.characters.last, last.isNewline {
            text.characters.removeLast()
        }
    }
}
