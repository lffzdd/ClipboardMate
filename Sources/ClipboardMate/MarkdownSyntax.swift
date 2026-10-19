import Foundation

/// Line-oriented Markdown constructs shared by detection and rendering.
///
/// Detection and `MarkdownRenderer` must agree on what a fence, heading, list,
/// or horizontal rule is. Payload languages are a separate concern: they run
/// on text outside these block structures, not on the whole clipboard blob.
enum MarkdownSyntax {

    struct FencePartition {
        /// Original lines with fenced bodies and fence markers removed.
        let outerLines: [String]
        /// Outer lines that appear before the first fence marker.
        let preambleLines: [String]
        /// Number of opened-and-closed fence pairs.
        let pairedFenceCount: Int
    }

    static func isFence(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("```")
    }

    static func isDisplayMathToggle(_ trimmedLine: String) -> Bool {
        trimmedLine == "$$" || trimmedLine == "\\[" || trimmedLine == "\\]"
    }

    static func singleLineDisplayMath(_ trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("$$"), trimmedLine.hasSuffix("$$"), trimmedLine.count >= 5 else { return nil }
        let inner = trimmedLine.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespaces)
        return inner.isEmpty ? nil : inner
    }

    static func fenceLanguageHint(_ trimmedLine: String) -> String? {
        guard isFence(trimmedLine) else { return nil }
        let hint = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return hint.isEmpty ? nil : hint
    }

    /// A thematic break: a line made of 3+ `-`, `*`, or `_` and nothing else.
    static func isHorizontalRule(_ trimmedLine: String) -> Bool {
        guard trimmedLine.count >= 3, let mark = trimmedLine.first, "-*_".contains(mark) else {
            return false
        }
        return trimmedLine.allSatisfy { $0 == mark }
    }

    static func atxHeadingLevel(_ trimmedLine: String) -> Int? {
        guard trimmedLine.hasPrefix("#") else { return nil }
        var level = 0
        for character in trimmedLine {
            if character == "#" {
                level += 1
                if level > 6 { return nil }
            } else {
                break
            }
        }
        guard (1...6).contains(level) else { return nil }
        let index = trimmedLine.index(trimmedLine.startIndex, offsetBy: level)
        guard index < trimmedLine.endIndex, trimmedLine[index] == " " else { return nil }
        return level
    }

    static func isBlockQuote(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix(">")
    }

    static func isTaskListItem(_ trimmedLine: String) -> Bool {
        isCheckedTaskListItem(trimmedLine) || trimmedLine.hasPrefix("- [ ] ")
    }

    static func isCheckedTaskListItem(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("- [x] ") || trimmedLine.hasPrefix("- [X] ")
    }

    static func isUnorderedListItem(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ")
    }

    static func isOrderedListItem(_ trimmedLine: String) -> Bool {
        trimmedLine.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil
    }

    /// GitHub Flavored Markdown tables are a header row plus a divider row.
    static func containsTable(in lines: [String]) -> Bool {
        guard lines.count >= 2 else { return false }
        for index in 0..<(lines.count - 1) {
            guard lines[index].contains("|") else { continue }
            var cells = lines[index + 1].trimmingCharacters(in: .whitespaces)
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.first?.isEmpty == true { cells.removeFirst() }
            if cells.last?.isEmpty == true { cells.removeLast() }
            guard cells.count >= 2 else { continue }
            if cells.allSatisfy({ $0.range(of: "^:?-+:?$", options: .regularExpression) != nil }) {
                return true
            }
        }
        return false
    }

    /// Walk lines the same way the renderer does: a trimmed line starting with
    /// ``` toggles a fence. Unclosed fences do not count as pairs.
    static func partitionFences(in lines: [String]) -> FencePartition {
        var outerLines: [String] = []
        var preambleLines: [String] = []
        var pairedFenceCount = 0
        var inFence = false
        var seenFence = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isFence(trimmed) {
                if inFence {
                    inFence = false
                    pairedFenceCount += 1
                } else {
                    if !seenFence {
                        preambleLines = outerLines
                        seenFence = true
                    }
                    inFence = true
                }
                continue
            }
            if !inFence {
                outerLines.append(line)
            }
        }

        if !seenFence {
            preambleLines = outerLines
        }
        return FencePartition(
            outerLines: outerLines,
            preambleLines: preambleLines,
            pairedFenceCount: pairedFenceCount
        )
    }
}

/// Clipboard text split into a Markdown container and a nested code payload.
///
/// Markdown is a document frame; Python/JS/etc. live inside it. Scoring and
/// code fingerprints therefore look at outer lines, not the raw blob.
struct SourceDocument {
    let partition: MarkdownSyntax.FencePartition

    var outerText: String {
        partition.outerLines.joined(separator: "\n")
    }

    var outerNonemptyLines: [String] {
        partition.outerLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    init(_ text: String) {
        partition = MarkdownSyntax.partitionFences(in: text.components(separatedBy: "\n"))
    }

    /// Strong document-frame signal. Wins over code tokens that only appear
    /// inside fences. A code file that happens to wrap a Markdown sample in a
    /// string is rejected via the preamble / skeleton checks.
    var isMarkdownContainer: Bool {
        if partition.pairedFenceCount >= 1 && !preambleLooksLikeCode {
            return true
        }
        if hasCodeSkeleton {
            return false
        }
        if containsTable {
            return true
        }
        return distinctBlockSignals >= 2 && (hasHeading || distinctBlockSignals >= 3)
    }

    /// Fallback score for unfenced notes. Threshold stays at 3 so a lone
    /// heading-like Python comment does not become Markdown.
    var markdownScore: Int {
        var score = 0
        if hasHeading { score += 2 }
        if partition.pairedFenceCount >= 1 && !preambleLooksLikeCode { score += 3 }
        if hasHorizontalRule { score += 2 }
        if hasBlockQuote { score += 1 }
        if hasTaskList { score += 2 }
        if hasLink { score += 1 }
        if hasBold { score += 2 }
        if hasInlineCode { score += 2 }

        if unorderedListCount >= 2 { score += 1 }
        if unorderedListCount >= 4 { score += 1 }
        if orderedListCount >= 2 { score += 1 }
        if orderedListCount >= 4 { score += 1 }
        if orderedListCount + unorderedListCount >= 8 { score += 1 }

        return score
    }

    var containsTable: Bool {
        MarkdownSyntax.containsTable(in: outerNonemptyLines)
    }

    private var hasHeading: Bool {
        outerNonemptyLines.contains { MarkdownSyntax.atxHeadingLevel($0) != nil }
    }

    private var hasHorizontalRule: Bool {
        outerNonemptyLines.contains { MarkdownSyntax.isHorizontalRule($0) }
    }

    private var hasBlockQuote: Bool {
        outerNonemptyLines.contains { MarkdownSyntax.isBlockQuote($0) }
    }

    private var hasTaskList: Bool {
        outerNonemptyLines.contains { MarkdownSyntax.isTaskListItem($0) }
    }

    private var unorderedListCount: Int {
        outerNonemptyLines.filter { MarkdownSyntax.isUnorderedListItem($0) }.count
    }

    private var orderedListCount: Int {
        outerNonemptyLines.filter { MarkdownSyntax.isOrderedListItem($0) }.count
    }

    private var distinctBlockSignals: Int {
        [
            hasHeading,
            hasHorizontalRule,
            hasBlockQuote,
            unorderedListCount >= 2,
            orderedListCount >= 2
        ].filter { $0 }.count
    }

    private var hasLink: Bool {
        let text = outerText
        return text.contains("](") && (text.contains("http://") || text.contains("https://"))
    }

    private var hasBold: Bool {
        guard let regex = RegexCache.mdBold else { return false }
        let text = outerText as NSString
        return regex.firstMatch(in: outerText, options: [], range: NSRange(location: 0, length: text.length)) != nil
    }

    private var hasInlineCode: Bool {
        guard let regex = RegexCache.mdInlineCode else { return false }
        let text = outerText as NSString
        return regex.firstMatch(in: outerText, options: [], range: NSRange(location: 0, length: text.length)) != nil
    }

    /// First fence is preceded by source-shaped lines (`def`, `import`, `src = """`).
    private var preambleLooksLikeCode: Bool {
        let preamble = partition.preambleLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = preamble.first else { return false }
        if Self.isCodeSkeletonLine(first) || Self.isMultilineStringAssignment(first) {
            return true
        }
        return preamble.prefix(8).filter(Self.isCodeSkeletonLine).count >= 2
    }

    /// Outer document still has top-level code structure, e.g. a Python module
    /// whose docstring contains headings and lists. A single `import` in prose
    /// is not enough; require a definition/shebang or two skeleton lines.
    private var hasCodeSkeleton: Bool {
        let hits = outerNonemptyLines.prefix(40).filter(Self.isCodeSkeletonLine)
        if hits.contains(where: { line in
            let l = line.lowercased()
            return l.hasPrefix("#!") || l.hasPrefix("def ") || l.hasPrefix("class ") ||
                l.hasPrefix("if __name__") || l.hasPrefix("func ") || l.hasPrefix("fn ") ||
                l.hasPrefix("int main(") || l.hasPrefix("public class ")
        }) {
            return true
        }
        return hits.count >= 2
    }

    private static func isMultilineStringAssignment(_ trimmed: String) -> Bool {
        trimmed.range(of: "=\\s*(\"\"\"|''')", options: .regularExpression) != nil
    }

    private static func isCodeSkeletonLine(_ trimmed: String) -> Bool {
        let line = trimmed.lowercased()
        if line.hasPrefix("#!") { return true }
        if line.hasPrefix("from ") && line.contains(" import ") { return true }
        if line.hasPrefix("import ") { return true }
        if line.hasPrefix("def ") && (line.contains("(") || line.hasSuffix(":")) { return true }
        if line.hasPrefix("class ") && (line.contains("(") || line.contains(":")) { return true }
        if line.hasPrefix("if __name__ ==") { return true }
        if line.hasPrefix("package ") { return true }
        if line.hasPrefix("func ") && line.contains("(") { return true }
        if line.hasPrefix("fn ") && line.contains("(") { return true }
        if line.hasPrefix("pub fn ") || line.hasPrefix("pub struct ") { return true }
        if line.hasPrefix("#include") { return true }
        if line.hasPrefix("public class ") || line.hasPrefix("public static ") { return true }
        if line.hasPrefix("int main(") { return true }
        if line.hasPrefix("export ") || line.hasPrefix("using ") { return true }
        return false
    }
}
