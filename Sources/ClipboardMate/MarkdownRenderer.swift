import AppKit
import Foundation

extension NSAttributedString.Key {
    /// Decorative Markdown chrome (language label, copy control) that must not
    /// appear in preview copy. Prose and code stay as shown.
    static let markdownChrome = NSAttributedString.Key("com.williamlao.clipboardmate.markdownChrome")
    static let markdownCodeCopyIndex = NSAttributedString.Key("com.williamlao.clipboardmate.markdownCodeCopyIndex")
}

extension NSAttributedString {
    func stringByRemovingMarkdownChrome() -> String {
        let mutable = NSMutableAttributedString(attributedString: self)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.markdownChrome, in: fullRange, options: .reverse) { value, range, _ in
            guard (value as? Bool) == true else { return }
            mutable.deleteCharacters(in: range)
        }
        return mutable.string
    }
}

/// Fenced code background. `NSTextBlock` has no corner radius, so the fill and stroke are drawn here.
final class RoundedCodeTextBlock: NSTextBlock {
    override func drawBackground(withFrame frameRect: NSRect, in controlView: NSView?, characterRange charRange: NSRange, layoutManager: NSLayoutManager) {
        let rect = frameRect.insetBy(dx: 0.5, dy: 0.5)
        guard rect.width > 2, rect.height > 2 else { return }
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        fillColor(for: controlView).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func fillColor(for view: NSView?) -> NSColor {
        let appearance = view?.effectiveAppearance ?? NSAppearance.currentDrawing()
        var resolved = NSColor.black.withAlphaComponent(0.045)
        appearance.performAsCurrentDrawingAppearance {
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            resolved = isDark
                ? NSColor.white.withAlphaComponent(0.08)
                : NSColor.black.withAlphaComponent(0.045)
        }
        return resolved
    }
}

/// 纯原生 Markdown 排版与排字引擎（0 外部依赖，精准保留结构换行、标题层级、列表缩进与代码块样式）
enum MarkdownRenderer {

    struct RenderedDocument {
        let text: NSAttributedString
        let codeBlocks: [String]
    }

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

    /// 将 Markdown 源码原生排版为带有自然换行、段落间距、标题层级、列表缩进与代码块的文档
    static func render(_ markdown: String, baseFontSize: CGFloat = 13) -> RenderedDocument {
        // 超过 40,000 字符硬件熔断保护，防止极端大文本阻塞主线程
        if markdown.count > 40_000 {
            return RenderedDocument(
                text: NSAttributedString(
                    string: markdown,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular),
                        .foregroundColor: NSColor.labelColor
                    ]
                ),
                codeBlocks: []
            )
        }

        let result = NSMutableAttributedString()
        var codeBlocks: [String] = []
        let lines = markdown.components(separatedBy: "\n")

        var inCodeBlock = false
        var codeBlockLang: String? = nil
        var codeBlockLines: [String] = []
        var inMathBlock = false
        var mathLines: [String] = []

        func flushCodeBlock() {
            guard !codeBlockLines.isEmpty || codeBlockLang != nil else { return }
            let codeContent = codeBlockLines.joined(separator: "\n")
            let blockIndex = codeBlocks.count
            codeBlocks.append(codeContent)

            let fenceLang = codeBlockLang.flatMap(CodeLanguage.fromFenceLanguage)
            let highlightLang = fenceLang ?? SyntaxHighlighter.detectLanguage(codeContent)
            let codeFontSize = max(11, baseFontSize - 1)
            let codeFont = NSFont.monospacedSystemFont(ofSize: codeFontSize, weight: .regular)
            let fenceBlock = makeCodeFenceTextBlock()

            result.append(makeCodeBlockChrome(
                label: codeBlockLabel(fenceHint: codeBlockLang, detected: highlightLang),
                blockIndex: blockIndex,
                baseFontSize: baseFontSize,
                fenceBlock: fenceBlock
            ))

            let layoutText = codeContent.hasSuffix("\n") ? String(codeContent.dropLast()) : codeContent
            let codeStyle = codeFenceParagraphStyle(fenceBlock: fenceBlock, alignment: .left, spacingBefore: 0)
            if layoutText.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: codeFont,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: codeStyle
                ]))
            } else {
                let codeAttr: NSMutableAttributedString
                if let highlightLang {
                    codeAttr = NSMutableAttributedString(attributedString: SyntaxHighlighter.highlight(code: layoutText, language: highlightLang, fontSize: codeFontSize))
                } else {
                    codeAttr = NSMutableAttributedString(
                        string: layoutText,
                        attributes: [
                            .font: codeFont,
                            .foregroundColor: NSColor.labelColor
                        ]
                    )
                }
                let fullRange = NSRange(location: 0, length: codeAttr.length)
                codeAttr.removeAttribute(.backgroundColor, range: fullRange)
                codeAttr.addAttribute(.paragraphStyle, value: codeStyle, range: fullRange)
                if !layoutText.hasSuffix("\n") {
                    codeAttr.append(NSAttributedString(string: "\n", attributes: [
                        .font: codeFont,
                        .paragraphStyle: codeStyle
                    ]))
                }
                result.append(codeAttr)
            }

            let tailStyle = NSMutableParagraphStyle()
            tailStyle.paragraphSpacingBefore = 8
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: NSFont.systemFont(ofSize: baseFontSize / 2),
                .paragraphStyle: tailStyle
            ]))

            codeBlockLines.removeAll()
            codeBlockLang = nil
        }

        func flushMathBlock() {
            let body = mathLines.joined(separator: "\n")
            mathLines.removeAll()
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let blockIndex = codeBlocks.count
            codeBlocks.append(body)
            let fontSize = max(11, baseFontSize - 1)
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let fenceBlock = makeCodeFenceTextBlock()
            result.append(makeCodeBlockChrome(
                label: L10n.mathFormula,
                blockIndex: blockIndex,
                baseFontSize: baseFontSize,
                fenceBlock: fenceBlock
            ))
            let style = codeFenceParagraphStyle(fenceBlock: fenceBlock, alignment: .left, spacingBefore: 0)
            let shown = body.hasSuffix("\n") ? body : body + "\n"
            result.append(NSAttributedString(string: shown, attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]))
            let tailStyle = NSMutableParagraphStyle()
            tailStyle.paragraphSpacingBefore = 8
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: NSFont.systemFont(ofSize: baseFontSize / 2),
                .paragraphStyle: tailStyle
            ]))
        }

        var lineIndex = 0
        while lineIndex < lines.count {
            defer { lineIndex += 1 }
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 1. 代码块围栏 ```
            if MarkdownSyntax.isFence(trimmed) {
                if inCodeBlock {
                    inCodeBlock = false
                    flushCodeBlock()
                } else {
                    inCodeBlock = true
                    codeBlockLang = MarkdownSyntax.fenceLanguageHint(trimmed)
                }
                continue
            }

            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }

            if let singleMath = MarkdownSyntax.singleLineDisplayMath(trimmed) {
                mathLines = [singleMath]
                flushMathBlock()
                continue
            }
            if MarkdownSyntax.isDisplayMathToggle(trimmed) {
                if inMathBlock {
                    inMathBlock = false
                    flushMathBlock()
                } else {
                    inMathBlock = true
                }
                continue
            }
            if inMathBlock {
                mathLines.append(line)
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
            if MarkdownSyntax.isHorizontalRule(trimmed) {
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
            if let level = MarkdownSyntax.atxHeadingLevel(trimmed) {
                let titleText = String(trimmed.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
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

            // 6. 引用块 (>)
            if MarkdownSyntax.isBlockQuote(trimmed) {
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

            if MarkdownSyntax.isCheckedTaskListItem(trimmed) {
                bulletPrefix = "☑  "
                bulletColor = NSColor.systemGreen
                lineContent = String(trimmed.dropFirst(6))
            } else if MarkdownSyntax.isTaskListItem(trimmed) {
                bulletPrefix = "☐  "
                bulletColor = NSColor.secondaryLabelColor
                lineContent = String(trimmed.dropFirst(6))
            } else if MarkdownSyntax.isUnorderedListItem(trimmed) {
                bulletPrefix = "•  "
                bulletColor = NSColor.systemBlue
                lineContent = String(trimmed.dropFirst(2))
            } else if MarkdownSyntax.isOrderedListItem(trimmed), let numMatch = trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
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
        flushMathBlock()
        return RenderedDocument(text: result, codeBlocks: codeBlocks)
    }

    private static func codeBlockLabel(fenceHint: String?, detected: CodeLanguage?) -> String {
        if let hint = fenceHint?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            return CodeLanguage.fromFenceLanguage(hint)?.displayName ?? hint
        }
        return detected?.displayName ?? L10n.codeLabel
    }

    private static func makeCodeFenceTextBlock() -> NSTextBlock {
        let block = RoundedCodeTextBlock()
        block.setValue(100, type: .percentageValueType, for: .width)
        block.setWidth(8, type: .absoluteValueType, for: .padding)
        block.setWidth(0, type: .absoluteValueType, for: .border)
        block.setWidth(0, type: .absoluteValueType, for: .margin)
        block.backgroundColor = .clear
        block.verticalAlignment = .topAlignment
        return block
    }

    private static func codeFenceParagraphStyle(
        fenceBlock: NSTextBlock,
        alignment: NSTextAlignment,
        spacingBefore: CGFloat
    ) -> NSParagraphStyle {
        let pStyle = NSMutableParagraphStyle()
        pStyle.textBlocks = [fenceBlock]
        pStyle.alignment = alignment
        pStyle.lineSpacing = 1
        pStyle.paragraphSpacing = 0
        pStyle.paragraphSpacingBefore = spacingBefore
        pStyle.lineBreakMode = .byWordWrapping
        pStyle.headIndent = 0
        pStyle.firstLineHeadIndent = 0
        return pStyle
    }

    private static func makeCodeBlockChrome(
        label: String,
        blockIndex: Int,
        baseFontSize: CGFloat,
        fenceBlock: NSTextBlock
    ) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: max(10, baseFontSize - 3), weight: .semibold)
        let pStyle = codeFenceParagraphStyle(fenceBlock: fenceBlock, alignment: .right, spacingBefore: 10)

        return NSAttributedString(string: label + "\n", attributes: [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: pStyle,
            .markdownChrome: true,
            .markdownCodeCopyIndex: blockIndex,
            .toolTip: "Copy"
        ])
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
        let pieces = inlineMathPieces(in: text)
        if pieces.contains(where: \.isMath) {
            let combined = NSMutableAttributedString()
            for piece in pieces {
                if piece.isMath {
                    combined.append(inlineMathAttributed(piece.text, baseFontSize: baseFontSize, pStyle: pStyle))
                } else if !piece.text.isEmpty {
                    combined.append(renderInlineMarkdown(piece.text, baseFontSize: baseFontSize, pStyle: pStyle, defaultColor: defaultColor, isItalic: isItalic, monospaced: monospaced, forceBold: forceBold))
                }
            }
            return combined
        }

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

    private struct InlineMathPiece {
        let text: String
        let isMath: Bool
    }

    /// Keeps `$...$` and `\(...\)` as formula source. A bare amount like `$12.50` is left alone.
    private static func inlineMathPieces(in text: String) -> [InlineMathPiece] {
        let chars = Array(text)
        var pieces: [InlineMathPiece] = []
        var plain = ""
        var index = 0

        func flushPlain() {
            guard !plain.isEmpty else { return }
            pieces.append(InlineMathPiece(text: plain, isMath: false))
            plain = ""
        }

        while index < chars.count {
            if chars[index] == "\\", index + 1 < chars.count, chars[index + 1] == "(" {
                if let end = closingDelimiter(in: chars, from: index + 2, first: "\\", second: ")") {
                    let inner = String(chars[(index + 2)..<end])
                    if isFormulaSource(inner) {
                        flushPlain()
                        pieces.append(InlineMathPiece(text: "\\(" + inner + "\\)", isMath: true))
                        index = end + 2
                        continue
                    }
                }
            }
            if chars[index] == "$", index == 0 || chars[index - 1] != "\\", index + 1 >= chars.count || chars[index + 1] != "$" {
                if let end = closingDollar(in: chars, from: index + 1) {
                    let inner = String(chars[(index + 1)..<end])
                    if isFormulaSource(inner) {
                        flushPlain()
                        pieces.append(InlineMathPiece(text: "$" + inner + "$", isMath: true))
                        index = end + 1
                        continue
                    }
                }
            }
            plain.append(chars[index])
            index += 1
        }
        flushPlain()
        if pieces.isEmpty {
            return [InlineMathPiece(text: text, isMath: false)]
        }
        return pieces
    }

    private static func closingDollar(in chars: [Character], from start: Int) -> Int? {
        var index = start
        while index < chars.count {
            if chars[index] == "$", index == 0 || chars[index - 1] != "\\" {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func closingDelimiter(in chars: [Character], from start: Int, first: Character, second: Character) -> Int? {
        var index = start
        while index + 1 < chars.count {
            if chars[index] == first, chars[index + 1] == second {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func isFormulaSource(_ inner: String) -> Bool {
        let trimmed = inner.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.range(of: #"^\d+([.,]\d+)?$"#, options: .regularExpression) == nil
    }

    private static func inlineMathAttributed(_ text: String, baseFontSize: CGFloat, pStyle: NSParagraphStyle) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: max(11, baseFontSize - 1), weight: .medium),
            .foregroundColor: NSColor.systemTeal,
            .backgroundColor: NSColor.quaternaryLabelColor,
            .paragraphStyle: pStyle
        ])
    }
}
