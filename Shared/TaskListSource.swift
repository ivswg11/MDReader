import Foundation

/// Edits task list markers (`- [ ]` / `- [x]`) in Markdown source.
enum TaskListSource {
    /// A list item line whose content starts with a task box, e.g. `  - [x] Ship it` or `1. [ ] Draft`.
    nonisolated(unsafe) private static let taskLine = #/^(\s*(?:>\s*)*(?:[-*+]|\d+[.)])\s+\[)([ xX])(\](?:\s|$))/#

    /// Returns `source` with the `index`-th task (in document order) checked or unchecked,
    /// or nil if there's no such task. Lines inside fenced code blocks are skipped.
    static func setting(_ index: Int, checked: Bool, in source: String) -> String? {
        var lines = source.components(separatedBy: "\n")
        var fence: String?
        var taskIndex = 0

        for lineIndex in lines.indices {
            let line = lines[lineIndex]
            let trimmed = line.drop { $0 == " " }
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fence = String(trimmed.prefix(3))
                continue
            }
            guard let task = line.prefixMatch(of: taskLine) else { continue }
            if taskIndex == index {
                let box: Character = checked ? "x" : " "
                lines[lineIndex] = String(task.output.1) + String(box) + line[task.output.3.startIndex...]
                return lines.joined(separator: "\n")
            }
            taskIndex += 1
        }
        return nil
    }
}
