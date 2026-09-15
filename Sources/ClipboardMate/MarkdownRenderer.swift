import AppKit
import Foundation

/// 纯原生 Markdown 排版与排字引擎（0 外部依赖，精准保留结构换行、标题层级、列表缩进与代码块样式）
enum MarkdownRenderer {

    private enum TableAlignment {
        case left, center, right
    }

    private struct MarkdownTable {
        let headers: [String]
        let alignments: [TableAlignment]
        let rows: [[String]]
        let source: String
        /// 第一行不属于表格的索引。
        let endIndex: Int
    }

    /// 将 Markdown 源码原生排版为带有自然换行、段落间距、标题层级、列表缩进与代码块的 NSAttributedString
    static func render(_ markdown: String, baseFontSize: CGFloat = 13) -> NSAttributedString {
        // 超过 40,000 字符硬件熔断保护，防止极端大文本阻塞主线程
        if markdown.count > 40_000 {
            return NSAttributedString(
                string: markdown,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        }

        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        var inCodeBlock = false
        var codeBlockLang: String? = nil
        var codeBlockLines: [String] = []

        func flushCodeBlock() {
            guard !codeBlockLines.isEmpty else { return }
            let codeContent = codeBlockLines.joined(separator: "\n")
            let codeFont = NSFont.monospacedSystemFont(ofSize: max(11, baseFontSize - 1), weight: .regular)

            let pStyle = NSMutableParagraphStyle()
            pStyle.lineSpacing = 2
            pStyle.paragraphSpacing = 8
            pStyle.headIndent = 8
            pStyle.firstLineHeadIndent = 8

            // 尝试对代码块进行语法高亮
            var codeAttr: NSMutableAttributedString
            let targetLang = codeBlockLang.flatMap(CodeLanguage.fromFenceLanguage)
            if let targetLang {
                codeAttr = NSMutableAttributedString(attributedString: SyntaxHighlighter.highlight(code: codeContent, language: targetLang, fontSize: max(11, baseFontSize - 1)))
            } else if let autoLang = SyntaxHighlighter.detectLanguage(codeContent) {
                codeAttr = NSMutableAttributedString(attributedString: SyntaxHighlighter.highlight(code: codeContent, language: autoLang, fontSize: max(11, baseFontSize - 1)))
            } else {
                codeAttr = NSMutableAttributedString(
                    string: codeContent,
                    attributes: [
                        .font: codeFont,
                        .foregroundColor: NSColor.labelColor
                    ]
                )
            }

            codeAttr.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: NSRange(location: 0, length: codeAttr.length))
            codeAttr.addAttribute(.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: codeAttr.length))

            result.append(codeAttr)
            result.append(NSAttributedString(string: "\n", attributes: [.font: codeFont, .paragraphStyle: pStyle]))
            codeBlockLines.removeAll()
            codeBlockLang = nil
        }

        var lineIndex = 0
        while lineIndex < lines.count {
            defer { lineIndex += 1 }
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 1. 代码块围栏 ```
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    flushCodeBlock()
                } else {
                    inCodeBlock = true
                    let langHint = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeBlockLang = langHint.isEmpty ? nil : langHint
                }
                continue
            }

            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }

            // 2. GitHub Flavored Markdown 表格。必须优先于普通行处理，
            // 这样表头与分隔行不会被各自渲染为两段文本。
            if let table = parseTable(lines: lines, startIndex: lineIndex) {
                appendTable(table, to: result, baseFontSize: baseFontSize)
                lineIndex = table.endIndex - 1
                continue
            }

            // 3. 空行
            if trimmed.isEmpty {
                let pStyle = NSMutableParagraphStyle()
                pStyle.paragraphSpacing = 6
                result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: baseFontSize / 2), .paragraphStyle: pStyle]))
                continue
            }

            // 4. 分割线 (---, ***, ___)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                let pStyle = NSMutableParagraphStyle()
                pStyle.paragraphSpacing = 6
                let hr = NSAttributedString(
                    string: "────────────────────────────────────────\n",
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: NSColor.separatorColor,
                        .paragraphStyle: pStyle
                    ]
                )
                result.append(hr)
                continue
            }

            // 5. 标题 (# ~ ######)
            if trimmed.hasPrefix("#") {
                var level = 0
                let chars = Array(trimmed)
                while level < chars.count && chars[level] == "#" {
                    level += 1
                }
                if level <= 6 && chars.count > level && chars[level] == " " {
                    let titleText = String(chars.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
                    let headerSize: CGFloat
                    switch level {
                    case 1: headerSize = baseFontSize + 6 // ~19pt
                    case 2: headerSize = baseFontSize + 4 // ~17pt
                    case 3: headerSize = baseFontSize + 2 // ~15pt
                    default: headerSize = baseFontSize + 1 // ~14pt
                    }

                    let pStyle = NSMutableParagraphStyle()
                    pStyle.paragraphSpacing = 6
                    pStyle.lineSpacing = 3

                    let headerAttr = NSMutableAttributedString(
                        string: titleText + "\n",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: headerSize, weight: .bold),
                            .foregroundColor: NSColor.labelColor,
                            .paragraphStyle: pStyle
                        ]
                    )
                    result.append(headerAttr)
                    continue
                }
            }

            // 6. 引用块 (>)
            if trimmed.hasPrefix(">") {
                let quoteText = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                let pStyle = NSMutableParagraphStyle()
                pStyle.headIndent = 12
                pStyle.firstLineHeadIndent = 12
                pStyle.lineSpacing = 3
                pStyle.paragraphSpacing = 3

                let prefix = NSAttributedString(
                    string: "▎ ",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: baseFontSize, weight: .bold),
                        .foregroundColor: NSColor.systemBlue,
                        .paragraphStyle: pStyle
                    ]
                )
                result.append(prefix)

                let quoteLine = renderInlineMarkdown(quoteText, baseFontSize: baseFontSize, pStyle: pStyle, defaultColor: NSColor.secondaryLabelColor, isItalic: true)
                result.append(quoteLine)
                result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: pStyle]))
                continue
            }

            // 7. 任务列表与普通列表
            var lineContent = trimmed
            var bulletPrefix: String? = nil
            var bulletColor = NSColor.systemBlue

            if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                bulletPrefix = "☑  "
                bulletColor = NSColor.systemGreen
                lineContent = String(trimmed.dropFirst(6))
            } else if trimmed.hasPrefix("- [ ] ") {
                bulletPrefix = "☐  "
                bulletColor = NSColor.secondaryLabelColor
                lineContent = String(trimmed.dropFirst(6))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                bulletPrefix = "•  "
                bulletColor = NSColor.systemBlue
                lineContent = String(trimmed.dropFirst(2))
            } else if let numMatch = trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                bulletPrefix = String(trimmed[numMatch])
                bulletColor = NSColor.systemBlue
                lineContent = String(trimmed[numMatch.upperBound...])
            }

            let pStyle = NSMutableParagraphStyle()
            pStyle.lineSpacing = 3
            pStyle.paragraphSpacing = 4

            if let bulletPrefix {
                pStyle.headIndent = 16
                pStyle.firstLineHeadIndent = 6
                let bulletAttr = NSAttributedString(
                    string: bulletPrefix,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: baseFontSize, weight: .bold),
                        .foregroundColor: bulletColor,
                        .paragraphStyle: pStyle
                    ]
                )
                result.append(bulletAttr)
            }

            let inlineFormatted = renderInlineMarkdown(lineContent, baseFontSize: baseFontSize, pStyle: pStyle)
            result.append(inlineFormatted)
            result.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: pStyle]))
        }

        flushCodeBlock()
        return result
    }

    // MARK: - GFM 表格

    private static func parseTable(lines: [String], startIndex: Int) -> MarkdownTable? {
        guard startIndex + 1 < lines.count,
              let headers = tableCells(from: lines[startIndex]),
              headers.count >= 2,
              let alignments = tableDividerAlignments(from: lines[startIndex + 1]),
              alignments.count == headers.count else {
            return nil
        }

        var rows: [[String]] = []
        var nextIndex = startIndex + 2
        while nextIndex < lines.count, let cells = tableCells(from: lines[nextIndex]) {
            guard cells.count == headers.count else { break }
            rows.append(cells)
            nextIndex += 1
        }
        return MarkdownTable(
            headers: headers,
            alignments: alignments,
            rows: rows,
            source: lines[startIndex..<nextIndex].joined(separator: "\n"),
            endIndex: nextIndex
        )
    }

    /// 按未转义的 `|` 切分单元格，并兼容首尾竖线省略。
    private static func tableCells(from line: String) -> [String]? {
        guard line.contains("|") else { return nil }
        var cells: [String] = []
        var current = ""
        var isEscaped = false

        for character in line {
            if isEscaped {
                current.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        if isEscaped { current.append("\\") }
        cells.append(current.trimmingCharacters(in: .whitespaces))

        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells.count >= 2 ? cells : nil
    }

    private static func tableDividerAlignments(from line: String) -> [TableAlignment]? {
        guard let cells = tableCells(from: line), cells.allSatisfy({
            $0.range(of: "^:?-+:?$", options: .regularExpression) != nil
        }) else {
            return nil
        }

        return cells.map { cell in
            let startsWithColon = cell.hasPrefix(":")
            let endsWithColon = cell.hasSuffix(":")
            if startsWithColon && endsWithColon { return .center }
            return endsWithColon ? .right : .left
        }
    }

    private static func appendTable(_ table: MarkdownTable, to result: NSMutableAttributedString, baseFontSize: CGFloat) {
        let nativeAlignments = nativeTableAlignments(in: table.source) ?? table.alignments
        let textTable = NSTextTable()
        textTable.numberOfColumns = table.headers.count
        textTable.layoutAlgorithm = .automaticLayoutAlgorithm
        textTable.collapsesBorders = true
        textTable.hidesEmptyCells = false

        let rows = [table.headers] + table.rows
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, cellText) in row.enumerated() {
                let block = NSTextTableBlock(
                    table: textTable,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: columnIndex,
                    columnSpan: 1
                )
                block.setWidth(1, type: .absoluteValueType, for: .border)
                block.setBorderColor(NSColor.separatorColor.withAlphaComponent(0.7))
                block.setWidth(6, type: .absoluteValueType, for: .padding)
                block.backgroundColor = rowIndex == 0 ? NSColor.quaternaryLabelColor : NSColor.clear

                let style = NSMutableParagraphStyle()
                style.lineSpacing = 2
                style.paragraphSpacing = 0
                style.textBlocks = [block]
                switch nativeAlignments[columnIndex] {
                case .left: style.alignment = .left
                case .center: style.alignment = .center
                case .right: style.alignment = .right
                }

                let cell = NSMutableAttributedString(attributedString: renderInlineMarkdown(
                    cellText,
                    baseFontSize: baseFontSize,
                    pStyle: style,
                    defaultColor: NSColor.labelColor,
                    monospaced: false,
                    forceBold: rowIndex == 0
                ))
                cell.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: style]))
                result.append(cell)
            }
        }
    }

    /// Foundation 完整 Markdown 解析器是表格结构与对齐的唯一权威来源。
    private static func nativeTableAlignments(in markdown: String) -> [TableAlignment]? {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full
        options.failurePolicy = .returnPartiallyParsedIfPossible
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else { return nil }

        for run in parsed.runs {
            guard let intent = run.presentationIntent else { continue }
            for component in intent.components {
                if case let .table(columns) = component.kind {
                    return columns.map { column in
                        switch column.alignment {
                        case .left: return .left
                        case .center: return .center
                        case .right: return .right
                        @unknown default: return .left
                        }
                    }
                }
            }
        }
        return nil
    }

    /// 渲染单行内的 Markdown 标记（粗体、斜体、删除线、行内代码、链接）
    private static func renderInlineMarkdown(_ text: String, baseFontSize: CGFloat, pStyle: NSParagraphStyle, defaultColor: NSColor = NSColor.labelColor, isItalic: Bool = false, monospaced: Bool = false, forceBold: Bool = false) -> NSAttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible

        guard let parsed = try? AttributedString(markdown: text, options: options) else {
            var font = monospaced ? NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: forceBold ? .semibold : .regular) : NSFont.systemFont(ofSize: baseFontSize, weight: forceBold ? .bold : .regular)
            if isItalic {
                let desc = font.fontDescriptor.withSymbolicTraits(.italic)
                font = NSFont(descriptor: desc, size: baseFontSize) ?? font
            }
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: defaultColor, .paragraphStyle: pStyle])
        }

        let lineResult = NSMutableAttributedString()
        for run in parsed.runs {
            let runText = String(parsed[run.range].characters)
            guard !runText.isEmpty else { continue }

            var runAttrs: [NSAttributedString.Key: Any] = [
                .paragraphStyle: pStyle,
                .foregroundColor: defaultColor
            ]
            var runFont = monospaced ? NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: forceBold ? .semibold : .regular) : NSFont.systemFont(ofSize: baseFontSize, weight: forceBold ? .bold : .regular)
            var runItalic = isItalic

            if let inline = run.inlinePresentationIntent {
                if inline.contains(.stronglyEmphasized) {
                    runFont = monospaced ? NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .semibold) : NSFont.systemFont(ofSize: baseFontSize, weight: .bold)
                }
                if inline.contains(.emphasized) {
                    runItalic = true
                }
                if inline.contains(.code) {
                    runFont = NSFont.monospacedSystemFont(ofSize: max(11, baseFontSize - 1), weight: .medium)
                    runAttrs[.backgroundColor] = NSColor.quaternaryLabelColor
                    runAttrs[.foregroundColor] = NSColor.systemPink
                }
                if inline.contains(.strikethrough) {
                    runAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
            }

            if let link = run.link {
                runAttrs[.foregroundColor] = NSColor.linkColor
                runAttrs[.link] = link
                runAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            if runItalic {
                let desc = runFont.fontDescriptor.withSymbolicTraits(.italic)
                runFont = NSFont(descriptor: desc, size: baseFontSize) ?? runFont
            }

            runAttrs[.font] = runFont
            lineResult.append(NSAttributedString(string: runText, attributes: runAttrs))
        }

        return lineResult
    }
}
