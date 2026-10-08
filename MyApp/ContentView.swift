import AppKit
import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument

    @AppStorage(SettingsKey.horizontalMargin) private var horizontalMargin = SettingsKey.defaultHorizontalMargin
    @AppStorage(SettingsKey.textScale) private var textScale = 1.0
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsKey.defaultFontSize
    @AppStorage(SettingsKey.fontFamily) private var fontFamily = ReaderFont.system
    @AppStorage(SettingsKey.headingFontFamily) private var headingFontFamily = ""
    @AppStorage(SettingsKey.theme) private var theme = ReaderTheme.default
    @AppStorage(SettingsKey.spacing) private var spacing = BlockSpacing.defaultBase

    @State private var blocks: [MarkdownBlock] = []
    @State private var scrollRequest: ScrollRequest?
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    /// The heading whose section is on screen; the sidebar highlights it.
    @State private var activeHeading: Int?
    /// After a sidebar click, scroll-driven updates wait until the jump has landed, so the
    /// clicked heading stays highlighted even if it can't reach the top (e.g. the last section).
    @State private var ignoreScrollUntil = Date.distantPast

    @State private var query = ""
    @State private var matches: [SearchMatch] = []
    @State private var currentMatch = 0
    @FocusState private var isSearchFocused: Bool

    private var palette: ReaderPalette? { theme.palette }

    private var style: ReaderStyle {
        ReaderStyle(
            scale: textScale * fontSize / SettingsKey.defaultFontSize,
            horizontalMargin: horizontalMargin,
            spacing: spacing,
            fontFamily: fontFamily,
            headingFontFamily: headingFontFamily.isEmpty ? nil : headingFontFamily,
            palette: palette
        )
    }

    private var headings: [MarkdownBlock] {
        blocks.filter { if case .heading = $0.kind { true } else { false } }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            OutlineView(headings: headings, activeHeading: activeHeading, palette: palette, onSelect: jump(to:))
                .navigationSplitViewColumnWidth(min: 160, ideal: 230, max: 360)
        } detail: {
            MarkdownReaderView(
                blocks: blocks,
                style: style,
                matches: matches,
                currentMatch: matches.isEmpty ? nil : currentMatch,
                scrollRequest: scrollRequest,
                onVisibleBlocksChange: updateActiveHeading,
                onToggleTask: setTask
            )
        }
        .preferredColorScheme(theme.colorScheme)
        .searchable(text: $query, placement: .toolbar, prompt: "Find")
        .searchFocusedIfAvailable($isSearchFocused)
        .onSubmit(of: .search) { showMatch(currentMatch + 1) }
        .toolbar {
            if !query.isEmpty {
                ToolbarItemGroup {
                    Text(matches.isEmpty ? "No matches" : "\(currentMatch + 1) of \(matches.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    ControlGroup {
                        Button("Previous Match", systemImage: "chevron.up") { showMatch(currentMatch - 1) }
                        Button("Next Match", systemImage: "chevron.down") { showMatch(currentMatch + 1) }
                    }
                    .disabled(matches.isEmpty)
                }
            }
        }
        .focusedSceneValue(\.findActions, FindActions(
            find: focusSearch,
            next: { showMatch(currentMatch + 1) },
            previous: { showMatch(currentMatch - 1) },
            hasMatches: !matches.isEmpty
        ))
        .onAppear(perform: reparse)
        .onChange(of: document.text) { _ in reparse() }
        .onChange(of: query) { _ in
            matches = SearchMatch.find(query, in: blocks)
            showMatch(0)
        }
    }

    private func reparse() {
        let isFirstLoad = blocks.isEmpty
        blocks = MarkdownParser.blocks(from: document.text)
        matches = SearchMatch.find(query, in: blocks)
        // Long documents open with the outline showing; short ones don't need it.
        if isFirstLoad, headings.count >= 3 { columnVisibility = .all }
    }

    /// macOS 13 and 14 can't focus a `.searchable` field from SwiftUI, so find it in the toolbar instead.
    private func focusSearch() {
        if #available(macOS 15, *) {
            isSearchFocused = true
        } else if let window = NSApp.keyWindow,
                  let field = window.toolbar?.items.lazy.compactMap({ $0.view?.firstSubview(of: NSSearchField.self) }).first {
            window.makeFirstResponder(field)
        }
    }

    private func jump(to headingID: Int) {
        activeHeading = headingID
        ignoreScrollUntil = .now + 0.6
        scrollRequest = ScrollRequest(blockID: headingID, flash: true)
    }

    /// The active heading is the last one at or above the top of the screen. At the very bottom,
    /// later headings can never scroll to the top, so the last one on screen wins instead.
    private func updateActiveHeading(visible: [Int]) {
        guard Date.now >= ignoreScrollUntil, let firstVisible = visible.first else { return }
        let atBottom = visible.last == blocks.indices.last
        if atBottom, firstVisible > 0, let last = headings.last(where: { visible.contains($0.id) }) {
            activeHeading = last.id
        } else {
            activeHeading = (headings.last { $0.id <= firstVisible } ?? headings.first)?.id
        }
    }

    /// Writes the checkbox state back into the Markdown. The document then autosaves to disk.
    private func setTask(_ index: Int, checked: Bool) {
        guard let updated = TaskListSource.setting(index, checked: checked, in: document.text) else { return }
        document.text = updated
    }

    /// Makes `index` (wrapping around) the current match and scrolls to its block.
    private func showMatch(_ index: Int) {
        guard !matches.isEmpty else {
            currentMatch = 0
            return
        }
        currentMatch = (index % matches.count + matches.count) % matches.count
        scrollRequest = ScrollRequest(blockID: matches[currentMatch].blockID)
    }
}

/// Headings in three visual tiers: the document's top level in bold, starting a new group;
/// the next level indented; the level after that smaller and dimmed. Deeper levels are left out.
private struct OutlineView: View {
    let headings: [MarkdownBlock]
    let activeHeading: Int?
    let palette: ReaderPalette?
    let onSelect: (Int) -> Void

    private struct Group: Identifiable {
        let id: Int
        var rows: [(block: MarkdownBlock, tier: Int)]
    }

    private var groups: [Group] {
        let topLevel = headings.map(level).min() ?? 1
        var groups: [Group] = []
        for heading in headings {
            let tier = level(of: heading) - topLevel
            guard tier <= 2 else { continue }
            if tier == 0 || groups.isEmpty {
                groups.append(Group(id: heading.id, rows: []))
            }
            groups[groups.count - 1].rows.append((heading, tier))
        }
        return groups
    }

    /// The highlighted row: the active heading, or its nearest shown parent if it's too deep to be listed.
    private var selectedRow: Int? {
        guard let activeHeading else { return nil }
        return groups.flatMap(\.rows).last { $0.block.id <= activeHeading }?.block.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: Binding(get: { selectedRow }, set: { if let id = $0 { onSelect(id) } })) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.rows, id: \.block.id) { row in
                            OutlineRow(title: String(row.block.text.characters), tier: row.tier)
                                .tag(row.block.id)
                                .id(row.block.id)
                        }
                    }
                }
            }
            // Long outlines follow along, so the highlighted row never scrolls out of the sidebar.
            .onChange(of: selectedRow) { selectedRow in
                guard let selectedRow else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(selectedRow) }
            }
        }
        .scrollContentBackground(palette == nil ? .automatic : .hidden)
        .background(palette?.sidebar ?? .clear)
        .overlay {
            if headings.isEmpty {
                if #available(macOS 14, *) {
                    ContentUnavailableView("No Headings", systemImage: "list.bullet.indent")
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 32))
                        Text("No Headings")
                            .font(.title3.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func level(of block: MarkdownBlock) -> Int {
        if case .heading(let level) = block.kind { level } else { 1 }
    }
}

private extension View {
    @ViewBuilder
    func searchFocusedIfAvailable(_ binding: FocusState<Bool>.Binding) -> some View {
        if #available(macOS 15, *) {
            searchFocused(binding)
        } else {
            self
        }
    }
}

private extension NSView {
    func firstSubview<T: NSView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let match = subview.firstSubview(of: type) { return match }
        }
        return nil
    }
}

private struct OutlineRow: View {
    let title: String
    let tier: Int

    var body: some View {
        Text(title)
            .lineLimit(tier == 0 ? 2 : 1)
            .font(.system(size: [13, 12, 11][tier], weight: tier == 0 ? .semibold : .regular))
            .foregroundStyle(tier == 2 ? .secondary : .primary)
            .padding(.leading, CGFloat(tier) * 14)
            .padding(.vertical, tier == 0 ? 2 : 0)
    }
}

#Preview {
    ContentView(document: .constant(MarkdownDocument(text: """
    # Heading
    Some **bold**, *italic* and `code` text with a [link](https://apple.com).

    ## Tasks
    - [ ] open
    - [x] done

    ## Quote
    > A quote

    ```swift
    let x = 1
    ```
    """)))
}
