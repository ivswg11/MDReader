import AppKit
import SwiftUI

/// A find-in-document hit: a range inside one block's text.
struct SearchMatch: Equatable {
    let blockID: Int
    let range: Range<AttributedString.Index>

    static func find(_ query: String, in blocks: [MarkdownBlock]) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }
        var matches: [SearchMatch] = []
        for block in blocks where block.kind != .rule {
            var start = block.text.startIndex
            while start < block.text.endIndex,
                  let range = block.text[start...].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
                matches.append(SearchMatch(blockID: block.id, range: range))
                start = range.upperBound
            }
        }
        return matches
    }
}

/// A request to scroll a block to the top of the reader. Each request has its own token,
/// so asking for the same block twice scrolls twice.
struct ScrollRequest: Equatable {
    let blockID: Int
    /// Briefly highlights the block after landing, so the eye finds where it went.
    var flash = false
    private let token = UUID()

    init(blockID: Int, flash: Bool = false) {
        self.blockID = blockID
        self.flash = flash
    }
}

/// The scrolling document body. Shared by the app window and the Quick Look preview.
struct MarkdownReaderView: View {
    let blocks: [MarkdownBlock]
    var style = ReaderStyle()
    var matches: [SearchMatch] = []
    var currentMatch: Int?
    var scrollRequest: ScrollRequest?
    /// Called with the IDs of the blocks on screen whenever they change, in document order.
    var onVisibleBlocksChange: (([Int]) -> Void)?
    /// Called when a task checkbox is clicked, with the task's index and new state.
    /// `nil` makes checkboxes read-only (Quick Look).
    var onToggleTask: ((Int, Bool) -> Void)?

    @State private var flashedBlockID: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Not lazy: every block has its real height from the start, so jumping to a heading far
                // down lands exactly and animates. Markdown files are small enough that this stays cheap.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks) { block in
                        BlockView(
                            block: block,
                            text: highlighted(block),
                            style: style,
                            isFlashed: block.id == flashedBlockID,
                            onToggleTask: onToggleTask
                        )
                        .padding(.top, gap(above: block))
                        .reportsFrame(id: block.id)
                    }
                }
                .scrollTargetLayoutIfAvailable()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, max(0, style.horizontalMargin))
                .padding(.vertical, 24)
            }
            .tracksVisibleBlocks { visible in
                onVisibleBlocksChange?(visible)
            }
            .onChange(of: scrollRequest) { scrollRequest in
                guard let scrollRequest else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    proxy.scrollTo(scrollRequest.blockID, anchor: .top)
                }
                if scrollRequest.flash { flash(scrollRequest.blockID) }
            }
        }
        .foregroundStyle(style.palette?.ink ?? .primary)
        .background(style.palette?.background ?? .clear)
    }

    /// Fades a highlight in behind the block, holds it, then fades it out.
    private func flash(_ blockID: Int) {
        withAnimation(.easeOut(duration: 0.15)) { flashedBlockID = blockID }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            guard flashedBlockID == blockID else { return }
            withAnimation(.easeInOut(duration: 0.6)) { flashedBlockID = nil }
        }
    }

    /// Block IDs are their positions in `blocks`, so the previous block is at `id - 1`.
    private func gap(above block: MarkdownBlock) -> CGFloat {
        let previous = block.id > 0 ? blocks[block.id - 1] : nil
        return BlockSpacing.ratio(before: block, after: previous) * style.spacing * style.scale
    }

    private func highlighted(_ block: MarkdownBlock) -> AttributedString {
        guard !matches.isEmpty else { return block.text }
        var text = block.text
        for (index, match) in matches.enumerated() where match.blockID == block.id {
            let isCurrent = index == currentMatch
            text[match.range].swiftUI.backgroundColor = isCurrent ? .orange : .yellow.opacity(0.35)
            if isCurrent { text[match.range].swiftUI.foregroundColor = .black }
        }
        return text
    }
}

private struct BlockView: View {
    let block: MarkdownBlock
    let text: AttributedString
    let style: ReaderStyle
    let isFlashed: Bool
    let onToggleTask: ((Int, Bool) -> Void)?

    private var scale: Double { style.scale }

    var body: some View {
        content
            .padding(.leading, block.quoteDepth > 0 ? 14 : 0)
            .overlay(alignment: .leading) {
                if block.quoteDepth > 0 {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.quaternary)
                        .frame(width: 3)
                }
            }
            .foregroundStyle(block.quoteDepth > 0 ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(isFlashed ? 0.2 : 0))
                    .padding(.horizontal, -8)
                    .padding(.vertical, -4)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch block.kind {
        case .heading(let level):
            Text(text)
                .font(headingFont(level))
        case .paragraph:
            Text(text)
                .font(bodyFont)
                .lineSpacing(3 * scale)
        case .listItem(let marker, let depth):
            HStack(alignment: .firstTextBaseline, spacing: 6 * scale) {
                if let task = block.task {
                    Toggle("Done", isOn: Binding(
                        get: { task.isChecked },
                        set: { onToggleTask?(task.index, $0) }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(onToggleTask == nil)
                    .frame(minWidth: 16 * scale, alignment: .trailing)
                } else {
                    Text(marker)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 16 * scale, alignment: .trailing)
                }
                Text(text)
                    .lineSpacing(3 * scale)
                    .strikethrough(block.task?.isChecked == true)
                    .foregroundStyle(block.task?.isChecked == true ? .secondary : .primary)
            }
            .font(bodyFont)
            .padding(.leading, CGFloat(depth - 1) * 22 * scale)
        case .code:
            CodeBlockView(text: text, source: String(block.text.characters), scale: scale)
        case .table:
            MonospacedBox(text: text, scale: scale)
        case .rule:
            Divider()
                .padding(.vertical, 6)
        }
    }

    private var bodyFont: Font {
        ReaderFont.font(style.fontFamily, size: 13 * scale)
    }

    /// macOS has no Dynamic Type, so sizes are the system text styles' point sizes times `scale`.
    private func headingFont(_ level: Int) -> Font {
        let family = style.headingFontFamily ?? style.fontFamily
        return switch level {
        case 1: ReaderFont.font(family, size: 26 * scale, weight: .bold)
        case 2: ReaderFont.font(family, size: 22 * scale, weight: .bold)
        case 3: ReaderFont.font(family, size: 17 * scale, weight: .semibold)
        case 4: ReaderFont.font(family, size: 15 * scale, weight: .semibold)
        default: ReaderFont.font(family, size: 13 * scale, weight: .bold)
        }
    }
}

private struct MonospacedBox: View {
    let text: AttributedString
    let scale: Double

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text)
                .font(.system(size: 12 * scale, design: .monospaced))
                .fixedSize()
                .padding(12 * scale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
    }
}

/// A code block with a copy button that appears on hover.
private struct CodeBlockView: View {
    let text: AttributedString
    let source: String
    let scale: Double

    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        MonospacedBox(text: text, scale: scale)
            .overlay(alignment: .topTrailing) {
                Button(action: copy) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .symbolReplaceTransition()
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
                .padding(6)
                .background(.regularMaterial, in: .rect(cornerRadius: 5))
                .padding(6)
                .help("Copy code")
                .opacity(isHovering || didCopy ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: isHovering)
            }
            .onHover { isHovering = $0 }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(source, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}

// MARK: - Compatibility with macOS 13 and 14

private extension View {
    @ViewBuilder
    func symbolReplaceTransition() -> some View {
        if #available(macOS 14, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    @ViewBuilder
    func scrollTargetLayoutIfAvailable() -> some View {
        if #available(macOS 14, *) {
            scrollTargetLayout()
        } else {
            self
        }
    }

    /// On macOS 13 and 14, publishes the block's frame so `tracksVisibleBlocks` can work out what's on screen.
    @ViewBuilder
    func reportsFrame(id: Int) -> some View {
        if #available(macOS 15, *) {
            self
        } else {
            background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: BlockFramesKey.self,
                        value: [id: geometry.frame(in: .named(readerScrollSpace))]
                    )
                }
            }
        }
    }

    /// Calls `action` with the IDs of the blocks that are at least 20% on screen, in document order.
    @ViewBuilder
    func tracksVisibleBlocks(_ action: @escaping ([Int]) -> Void) -> some View {
        if #available(macOS 15, *) {
            onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.2) { visible in
                action(visible.sorted())
            }
        } else {
            modifier(FrameVisibilityTracker(action: action))
        }
    }
}

private let readerScrollSpace = "MarkdownReaderScroll"

private struct BlockFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct FrameVisibilityTracker: ViewModifier {
    let action: ([Int]) -> Void

    @State private var visible: [Int] = []

    func body(content: Content) -> some View {
        GeometryReader { viewport in
            content
                .coordinateSpace(name: readerScrollSpace)
                .onPreferenceChange(BlockFramesKey.self) { frames in
                    let bounds = CGRect(origin: .zero, size: viewport.size)
                    let ids = frames
                        .filter { _, frame in
                            frame.height > 0 && frame.intersection(bounds).height / frame.height >= 0.2
                        }
                        .map(\.key)
                        .sorted()
                    guard ids != visible else { return }
                    visible = ids
                    action(ids)
                }
        }
    }
}
