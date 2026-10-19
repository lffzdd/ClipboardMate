import AppKit
import Foundation

/// 识别出的代码语言类型
enum CodeLanguage: String, CaseIterable {
    case shell = "Shell"
    case json = "JSON"
    case yaml = "YAML"
    case markdown = "Markdown"
    case sql = "SQL"
    case html = "HTML"
    case xml = "XML"
    case css = "CSS"
    case swift = "Swift"
    case go = "Go"
    case rust = "Rust"
    case cpp = "C/C++"
    case java = "Java"
    case kotlin = "Kotlin"
    case python = "Python"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case php = "PHP"
    case generic = "Code"

    /// 将 Markdown 围栏中常见的语言标记规范化为内部类型。
    /// 围栏标记并不遵循 `rawValue` 的展示名称，例如 `js`、`c++`、`yml`。
    static func fromFenceLanguage(_ hint: String) -> CodeLanguage? {
        let normalized = hint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let aliases: [String: CodeLanguage] = [
            "sh": .shell, "shell": .shell, "bash": .shell, "zsh": .shell, "fish": .shell,
            "json": .json, "jsonc": .json,
            "yaml": .yaml, "yml": .yaml,
            "md": .markdown, "markdown": .markdown,
            "sql": .sql,
            "html": .html, "htm": .html,
            "xml": .xml, "svg": .xml,
            "css": .css,
            "swift": .swift,
            "go": .go, "golang": .go,
            "rs": .rust, "rust": .rust,
            "c": .cpp, "cc": .cpp, "cpp": .cpp, "cxx": .cpp, "c++": .cpp, "h": .cpp, "hpp": .cpp,
            "java": .java,
            "kt": .kotlin, "kts": .kotlin, "kotlin": .kotlin,
            "py": .python, "python": .python, "python3": .python,
            "js": .javascript, "jsx": .javascript, "javascript": .javascript,
            "ts": .typescript, "tsx": .typescript, "typescript": .typescript,
            "php": .php
        ]
        return aliases[normalized]
    }

    var displayName: String {
        switch self {
        case .shell: return "Shell"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .markdown: return "Markdown"
        case .sql: return "SQL"
        case .html: return "HTML"
        case .xml: return "XML"
        case .css: return "CSS"
        case .swift: return "Swift"
        case .go: return "Go"
        case .rust: return "Rust"
        case .cpp: return "C/C++"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .php: return "PHP"
        case .generic: return L10n.codeLabel
        }
    }
}

// MARK: - 静态正则缓存池（一次编译，多处高性能复用）

struct RegexCache {
    // 字符串与注释
    static let doubleQuote = try? NSRegularExpression(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", options: [])
    static let singleQuote = try? NSRegularExpression(pattern: "'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", options: [])
    static let backtick = try? NSRegularExpression(pattern: "`[^`\\\\]*(?:\\\\.[^`\\\\]*)*`", options: [])
    static let slashComment = try? NSRegularExpression(pattern: "(?m)//.*$", options: [])
    static let hashComment = try? NSRegularExpression(pattern: "(?m)#.*$", options: [])
    static let blockComment = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/", options: [])
    static let number = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b", options: [])
    static let identifier = try? NSRegularExpression(pattern: "\\b[a-zA-Z_][a-zA-Z0-9_]*\\b", options: [])
    static let decorator = try? NSRegularExpression(pattern: "@[a-zA-Z_][a-zA-Z0-9_]*", options: [])

    // Shell 专用
    static let shellFlag = try? NSRegularExpression(pattern: "(?<!\\w)-{1,2}[a-zA-Z0-9_-]+", options: [])
    static let shellVariable = try? NSRegularExpression(pattern: "\\$[a-zA-Z_][a-zA-Z0-9_]*|\\$\\{[^}]+\\}|\\$\\d", options: [])
    static let shellOperator = try? NSRegularExpression(pattern: "(\\|{1,2}|&&|>>|>|<|2>&1|\\\\)", options: [])
    static let url = try? NSRegularExpression(pattern: "https?://[^\\s\"'<>]+", options: [])

    // JSON 专用
    static let jsonKey = try? NSRegularExpression(pattern: "\"([^\"]+)\"\\s*:", options: [])

    // YAML 专用
    static let yamlKey = try? NSRegularExpression(pattern: "(?m)^[ \t]*([a-zA-Z0-9_.-]+)[ \t]*:", options: [])
    static let yamlBullet = try? NSRegularExpression(pattern: "(?m)^[ \t]*-[ \t]+", options: [])

    // Markdown 专用
    static let mdHeader = try? NSRegularExpression(pattern: "(?m)^#{1,6}[ \t]+.*$", options: [])
    static let mdLink = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: [])
    static let mdCodeBlock = try? NSRegularExpression(pattern: "```[\\s\\S]*?```|`[^`\\n]+`", options: [])
    static let mdInlineCode = try? NSRegularExpression(pattern: "(?<!`)`[^`\\n]+`(?!`)", options: [])
    static let mdList = try? NSRegularExpression(pattern: "(?m)^[ \t]*([*+-]|\\d+\\.)[ \t]+", options: [])
    static let mdBold = try? NSRegularExpression(pattern: "\\*\\*[^*\\n]+\\*\\*|__[^_\\n]+__", options: [])
    static let mdQuote = try? NSRegularExpression(pattern: "(?m)^[ \t]*>.*$", options: [])

    // C/C++ 专用
    static let cppPreprocessor = try? NSRegularExpression(pattern: "(?m)^[ \t]*#[a-zA-Z_]+", options: [])

    // Rust 专用
    static let rustMacro = try? NSRegularExpression(pattern: "\\b[a-zA-Z_][a-zA-Z0-9_]*!", options: [])

    // PHP 专用
    static let phpVariable = try? NSRegularExpression(pattern: "\\$[a-zA-Z_\\x80-\\xff][a-zA-Z0-9_\\x80-\\xff]*", options: [])
    static let phpTag = try? NSRegularExpression(pattern: "<\\?php|<\\?=|\\?>", options: [])

    // HTML / XML 专用
    static let xmlComment = try? NSRegularExpression(pattern: "<!--[\\s\\S]*?-->", options: [])
    static let xmlTag = try? NSRegularExpression(pattern: "</?[a-zA-Z0-9_-]+", options: [])
    static let xmlAttr = try? NSRegularExpression(pattern: "\\s+([a-zA-Z0-9_:-]+)(?=\\=)", options: [])
    static let completeMarkupTag = try? NSRegularExpression(pattern: "</?[a-zA-Z_][a-zA-Z0-9_.:-]*(?:\\s+[^<>]*)?/?>", options: [])

    // CSS 专用
    static let cssProp = try? NSRegularExpression(pattern: "[a-zA-Z0-9_-]+(?=\\s*:)", options: [])
    static let cssUnit = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?(px|rem|em|%|vh|vw|s|ms)?\\b", options: [])
}

// MARK: - 语法高亮核心引擎

enum SyntaxHighlighter {

    // MARK: - 词汇字典表

    private static let shellCommands: Set<String> = [
        "curl", "git", "docker", "docker-compose", "kubectl", "npm", "yarn", "pnpm", "brew", "sudo",
        "chmod", "chown", "export", "cd", "mkdir", "rm", "cp", "mv", "ls", "grep", "cat", "ssh",
        "scp", "tar", "find", "pip", "pip3", "python", "python3", "node", "go", "cargo", "swift",
        "source", "systemctl", "service", "make", "echo", "kill", "ps", "awk", "sed", "which",
        "apt", "apt-get", "yum", "wget", "bash", "zsh", "sh", "env", "clear", "tail", "head",
        "less", "more", "zip", "unzip", "touch", "nano", "vim", "alias", "sleep", "exit", "whoami",
        "pwd", "crontab", "df", "du", "top", "htop", "ping", "netstat", "lsof", "tee", "xargs", "rsync"
    ]

    private static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done",
        "in", "function", "select", "return"
    ]

    private static let sqlKeywords: Set<String> = [
        "select", "from", "where", "insert", "into", "update", "set", "delete", "table", "join",
        "inner", "left", "right", "outer", "cross", "on", "group", "by", "order", "having",
        "limit", "offset", "union", "all", "create", "alter", "drop", "index", "view", "and",
        "or", "not", "in", "is", "null", "like", "between", "exists", "case", "when", "then",
        "else", "end", "as", "distinct", "count", "sum", "avg", "min", "max", "primary",
        "key", "foreign", "references", "default", "values", "database", "schema"
    ]

    private static let commonLiterals: Set<String> = [
        "true", "false", "nil", "null", "none", "undefined", "nan", "yes", "no"
    ]

    // MARK: - 各语言专用词汇表

    private static let goKeywords: Set<String> = [
        "package", "import", "func", "return", "var", "const", "type", "struct", "interface",
        "map", "chan", "go", "defer", "if", "else", "for", "range", "switch", "case", "default",
        "select", "break", "continue", "fallthrough", "goto"
    ]
    private static let goTypes: Set<String> = [
        "string", "bool", "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16",
        "uint32", "uint64", "uintptr", "byte", "rune", "float32", "float64", "complex64",
        "complex128", "error", "any"
    ]

    private static let rustKeywords: Set<String> = [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
        "extern", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move",
        "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait",
        "type", "unsafe", "use", "where", "while"
    ]
    private static let rustTypes: Set<String> = [
        "bool", "char", "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64",
        "u128", "usize", "f32", "f64", "str", "String", "Option", "Some", "None", "Result",
        "Ok", "Err", "Vec", "Box", "Rc", "Arc"
    ]

    private static let cppKeywords: Set<String> = [
        "auto", "break", "case", "catch", "class", "const", "constexpr", "continue", "default",
        "delete", "do", "else", "enum", "explicit", "export", "extern", "final", "for", "friend",
        "goto", "if", "inline", "mutable", "namespace", "new", "noexcept", "operator", "override",
        "private", "protected", "public", "return", "sizeof", "static", "struct", "switch",
        "template", "this", "throw", "try", "typedef", "typeid", "typename", "union", "using",
        "virtual", "volatile", "while"
    ]
    private static let cppTypes: Set<String> = [
        "void", "bool", "char", "int", "float", "double", "short", "long", "signed", "unsigned",
        "size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "int8_t", "int16_t", "int32_t",
        "int64_t", "string", "vector", "map", "set", "unique_ptr", "shared_ptr"
    ]

    private static let javaKeywords: Set<String> = [
        "abstract", "assert", "break", "case", "catch", "class", "const", "continue", "default",
        "do", "else", "enum", "extends", "final", "finally", "for", "goto", "if", "implements",
        "import", "instanceof", "interface", "native", "new", "package", "private", "protected",
        "public", "return", "static", "strictfp", "super", "switch", "synchronized", "this",
        "throw", "throws", "transient", "try", "volatile", "while", "record"
    ]
    private static let javaTypes: Set<String> = [
        "void", "boolean", "byte", "char", "short", "int", "long", "float", "double", "String",
        "Object", "Integer", "List", "Map", "Set", "ArrayList", "HashMap"
    ]

    private static let kotlinKeywords: Set<String> = [
        "as", "break", "class", "continue", "do", "else", "for", "fun", "if", "in", "interface",
        "is", "object", "package", "return", "super", "this", "throw", "try", "typealias", "val",
        "var", "when", "while", "by", "catch", "constructor", "data", "dynamic", "enum", "external",
        "final", "finally", "get", "import", "infix", "init", "inline", "inner", "internal",
        "lateinit", "noinline", "open", "operator", "out", "override", "private", "protected",
        "public", "reified", "sealed", "set", "suspend", "tailrec", "vararg", "companion"
    ]

    private static let phpKeywords: Set<String> = [
        "function", "class", "public", "private", "protected", "static", "return", "echo", "print",
        "if", "else", "elseif", "while", "do", "for", "foreach", "as", "switch", "case", "default",
        "break", "continue", "try", "catch", "finally", "throw", "new", "namespace", "use",
        "require", "require_once", "include", "include_once", "extends", "implements", "interface",
        "trait", "abstract", "final", "yield", "fn", "match"
    ]

    private static let swiftKeywords: Set<String> = [
        "func", "let", "var", "class", "struct", "enum", "protocol", "extension", "init", "deinit",
        "typealias", "associatedtype", "import", "return", "guard", "if", "else", "for", "in",
        "while", "repeat", "switch", "case", "default", "break", "continue", "fallthrough", "defer",
        "throw", "throws", "rethrows", "try", "catch", "do", "async", "await", "actor", "public",
        "private", "fileprivate", "internal", "open", "static", "final", "mutating", "nonmutating",
        "override", "convenience", "required", "weak", "unowned", "lazy", "inout", "some", "any",
        "self", "Self"
    ]

    private static let pythonKeywords: Set<String> = [
        "def", "class", "return", "if", "elif", "else", "for", "while", "break", "continue",
        "try", "except", "finally", "raise", "import", "from", "as", "with", "pass", "lambda",
        "yield", "global", "nonlocal", "assert", "async", "await", "in", "is", "not", "and", "or"
    ]

    private static let jsKeywords: Set<String> = [
        "function", "const", "let", "var", "return", "if", "else", "for", "while", "do", "switch",
        "case", "default", "break", "continue", "try", "catch", "finally", "throw", "import",
        "export", "from", "as", "class", "extends", "super", "this", "new", "typeof", "instanceof",
        "void", "delete", "yield", "async", "await", "interface", "type", "enum", "implements",
        "namespace", "declare", "abstract", "readonly", "keyof", "is"
    ]

    private static let genericKeywords: Set<String> = [
        "func", "function", "def", "let", "var", "val", "const", "class", "struct", "enum",
        "protocol", "interface", "type", "import", "export", "from", "as", "return", "guard",
        "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
        "try", "catch", "throw", "throws", "async", "await", "public", "private", "protected",
        "internal", "fileprivate", "open", "static", "final", "override", "init", "self", "Self"
    ]

    // MARK: - 语言指纹检测

    /// 识别文本的代码语言类型。
    /// Markdown 是文档容器，其它语言是载荷；围栏里的 Python 不能把整篇判成 Python。
    static func detectLanguage(_ text: String) -> CodeLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if looksLikeJSON(trimmed) {
            return .json
        }

        let document = SourceDocument(trimmed)
        if document.isMarkdownContainer {
            return .markdown
        }
        if let payload = detectPayloadLanguage(
            trimmed: document.outerText.trimmingCharacters(in: .whitespacesAndNewlines),
            lines: document.outerNonemptyLines
        ) {
            return payload
        }
        if document.containsTable || document.markdownScore >= 3 {
            return .markdown
        }
        if looksLikeCode(document.outerText) {
            return .generic
        }
        return nil
    }

    private static func looksLikeJSON(_ trimmed: String) -> Bool {
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
              (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else {
            return false
        }
        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }

    /// Code / markup fingerprints. Callers must pass fence-stripped outer text.
    private static func detectPayloadLanguage(trimmed: String, lines: [String]) -> CodeLanguage? {
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()

        if lower.contains("<?php") || lower.hasPrefix("<?=") ||
           (lower.contains("$this->") && (lower.contains("function") || lower.contains("class"))) {
            return .php
        }

        let markupTagCount = RegexCache.completeMarkupTag?
            .numberOfMatches(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length)) ?? 0
        let startsWithMarkup = trimmed.hasPrefix("<")
        if lower.contains("<!doctype html") ||
           (startsWithMarkup && (lower.contains("<html") || lower.contains("<body") || lower.contains("<head"))) ||
           (startsWithMarkup && markupTagCount >= 2 && (lower.contains("</div>") || lower.contains("</span>") || lower.contains("</p>") || lower.contains("</script>") || lower.contains("</a>"))) {
            return .html
        }
        if lower.hasPrefix("<?xml") || (startsWithMarkup && markupTagCount >= 2) {
            return .xml
        }

        if trimmed.hasPrefix("#!/bin/bash") || trimmed.hasPrefix("#!/bin/sh") ||
           trimmed.hasPrefix("#!/usr/bin/env bash") || trimmed.hasPrefix("#!/usr/bin/env zsh") ||
           trimmed.hasPrefix("#!/bin/zsh") {
            return .shell
        }
        if let firstLine = lines.first {
            let fl = firstLine.lowercased()
            let isShellPrompt = fl.hasPrefix("$ ") || fl.hasPrefix("# ")
            let cleanFirst = isShellPrompt ? String(fl.dropFirst(2)).trimmingCharacters(in: .whitespaces) : fl
            let startsWithCommand = shellCommands.contains { cmd in
                cleanFirst == cmd || cleanFirst.hasPrefix(cmd + " ") || cleanFirst.hasPrefix(cmd + "\t")
            }
            if startsWithCommand {
                return .shell
            }
        }
        var commandHits = 0
        var syntaxHits = 0
        for line in lines.prefix(15) {
            let l = line.lowercased()
            if shellCommands.contains(where: { l.hasPrefix($0 + " ") || l == $0 }) {
                commandHits += 1
            } else if l.hasPrefix("--") || (l.hasPrefix("-") && !l.hasPrefix("- ")) || l.hasSuffix("\\") || l.contains(" | ") {
                syntaxHits += 1
            }
        }
        if commandHits >= 1 && (commandHits + syntaxHits >= 2) && lines.count <= 25 {
            return .shell
        }

        if looksLikeSQL(trimmed.lowercased()) {
            return .sql
        }

        let swiftMarkers = ["import swiftui", "import appkit", "import uikit", "import foundation", "guard let", "if let", "@state", "@binding", "mutating func", "override func", "public func", "private func"]
        for marker in swiftMarkers {
            if lower.contains(marker) { return .swift }
        }
        if lower.contains("func ") && lower.contains(" -> ") {
            return .swift
        }

        if lower.hasPrefix("package ") || lines.contains(where: { $0.hasPrefix("package ") }) {
            return .go
        }
        if (lower.contains("func ") && (lower.contains("(") && lower.contains(")") && lower.contains("{"))) &&
           (lower.contains("go func") || lower.contains("err != nil") || lower.contains("fmt.println") || lower.contains("defer ") || lower.contains("chan ") || lower.contains("make(")) {
            return .go
        }

        if lower.contains("fn main()") || lower.contains("let mut ") || lower.contains("println!") ||
           lower.contains("pub struct ") || lower.contains("impl ") || lower.contains("derive(") ||
           (lower.contains("pub fn ") && lower.contains("->")) {
            return .rust
        }

        if lower.contains("#include <") || lower.contains("#include \"") ||
           lower.contains("int main(") || lower.contains("std::") || lower.contains("cout <<") || lower.contains("nullptr") ||
           lower.contains("template<") || lower.contains("template <") {
            return .cpp
        }

        if lower.contains("public class ") || lower.contains("public static void main") ||
           lower.contains("system.out.println") || lower.contains("import java.") ||
           (lower.contains("public interface ") && lower.contains("{")) {
            return .java
        }

        if lower.contains("fun main(") || lower.contains("data class ") || lower.contains("companion object") ||
           lower.contains("sealed class ") || lower.contains("suspend fun ") ||
           (lower.contains("fun ") && (lower.contains("val ") || lower.contains("var "))) {
            return .kotlin
        }

        if looksLikePython(trimmed: trimmed, lines: lines) {
            return .python
        }

        if lower.contains("{") && lower.contains("}") &&
           (lower.contains("px;") || lower.contains("rem;") || lower.contains("color:") || lower.contains("display:") || lower.contains("margin:") || lower.contains("padding:")) {
            return .css
        }

        if (lower.contains("interface ") && lower.contains("{") && lower.contains(":")) ||
           (lower.contains("type ") && lower.contains(" = ")) || lower.contains("as const") {
            return .typescript
        }
        let jsMarkers = ["console.log", "export default", "const ", "let ", "function(", "=> {", "require('", "import {"]
        var jsScore = 0
        for m in jsMarkers {
            if lower.contains(m) { jsScore += 1 }
        }
        if jsScore >= 2 {
            return .javascript
        }

        if looksLikeYAML(trimmed: trimmed, lines: lines, lower: lower) {
            return .yaml
        }

        return nil
    }

    private static func looksLikePython(trimmed: String, lines: [String]) -> Bool {
        if trimmed.hasPrefix("#!/usr/bin/env python") || trimmed.hasPrefix("#!/usr/bin/python") {
            return true
        }
        if lines.contains(where: { line in
            let l = line.lowercased()
            return l.hasPrefix("def __init__") ||
                (l.hasPrefix("def ") && l.contains("(")) ||
                l.hasPrefix("if __name__ == '__main__':") ||
                l.hasPrefix("if __name__ == \"__main__\":")
        }) {
            return true
        }
        var pyScore = 0
        if lines.contains(where: { $0.hasPrefix("def ") && $0.contains(":") }) { pyScore += 2 }
        if lines.contains(where: { $0.hasPrefix("elif ") && $0.contains(":") }) { pyScore += 1 }
        if lines.contains(where: { $0.contains("self.") }) { pyScore += 2 }
        return pyScore >= 3
    }

    /// A leading `---` is YAML front matter only when mapping keys follow.
    /// A Markdown thematic break must not win this check by itself.
    private static func looksLikeYAML(trimmed: String, lines: [String], lower: String) -> Bool {
        let hasTypicalKeys = lower.contains("version:") || lower.contains("services:") ||
            lower.contains("name:") || lower.contains("image:") || lower.contains("spec:")
        let mappingShaped = lines.count >= 2 &&
            lines.prefix(8).allSatisfy { line in
                line.hasPrefix("#") || line.contains(":") || line.hasPrefix("- ") || line.isEmpty
            } && !lower.contains("{") && !lower.contains(";") && hasTypicalKeys
        if mappingShaped {
            return true
        }
        guard trimmed.hasPrefix("---") else { return false }
        return lines.dropFirst().prefix(12).contains { line in
            line.contains(":") && !MarkdownSyntax.isHorizontalRule(line)
        }
    }

    /// 对自然语言说明中的子串命中保持保守，例如 `update` 不应匹配 `updated`。
    private static func containsWholeWord(_ word: String, in text: String) -> Bool {
        let pattern = "(?<![a-z0-9_])" + NSRegularExpression.escapedPattern(for: word) + "(?![a-z0-9_])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    /// SQL 必须呈现语句的起始与从句结构，不能仅因自然语言里出现 select/from/update 而命中。
    private static func looksLikeSQL(_ text: String) -> Bool {
        if text.hasPrefix("select ") {
            return containsWholeWord("from", in: text)
        }
        return text.hasPrefix("insert into ") ||
            text.hasPrefix("update ") && containsWholeWord("set", in: text) ||
            text.hasPrefix("delete from ") ||
            text.hasPrefix("create table ") ||
            text.hasPrefix("alter table ") ||
            text.hasPrefix("drop table ")
    }

    /// 启发式判断文本是否为代码/结构化文本
    static func looksLikeCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) ||
           (trimmed.hasPrefix("<") && trimmed.hasSuffix(">")) {
            return true
        }
        let lower = text.lowercased()
        let sample = lower.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        var codeScore = 0
        for word in sample.prefix(40) {
            // SQL 与单独的布尔/空值字面量易出现在自然语言中；它们已在各自
            // 的结构化规则中处理，不应让通用兜底重新把说明文本误判为代码。
            if genericKeywords.contains(word) || shellCommands.contains(word) {
                codeScore += 1
            }
        }
        return codeScore >= 2
    }

    // MARK: - 高亮渲染总入口

    /// 高亮代码（支持指定语言）
    static func highlight(code: String, language: CodeLanguage? = nil, fontSize: CGFloat = 12) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        let baseColor = NSColor.labelColor

        let mutable = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: font,
                .foregroundColor: baseColor
            ]
        )

        // 超过 40,000 字符防止主线程卡顿
        if code.count > 40_000 {
            return mutable
        }

        let fullRange = NSRange(location: 0, length: (code as NSString).length)
        let lang = language ?? detectLanguage(code) ?? .generic

        switch lang {
        case .shell:
            highlightShell(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont)
        case .json:
            highlightJSON(mutable: mutable, code: code, fullRange: fullRange, boldFont: boldFont)
        case .yaml:
            highlightYAML(mutable: mutable, code: code, fullRange: fullRange, boldFont: boldFont)
        case .markdown:
            highlightMarkdown(mutable: mutable, code: code, fullRange: fullRange, boldFont: boldFont)
        case .html, .xml:
            highlightHTMLorXML(mutable: mutable, code: code, fullRange: fullRange, boldFont: boldFont)
        case .sql:
            highlightSQL(mutable: mutable, code: code, fullRange: fullRange, boldFont: boldFont)
        case .css:
            highlightCSS(mutable: mutable, code: code, fullRange: fullRange, boldFont: boldFont)
        case .go:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: goKeywords, types: goTypes, allowBacktickString: true)
        case .rust:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: rustKeywords, types: rustTypes, isRust: true)
        case .cpp:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: cppKeywords, types: cppTypes, isCPP: true)
        case .java:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: javaKeywords, types: javaTypes, hasDecorators: true)
        case .kotlin:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: kotlinKeywords, types: javaTypes, hasDecorators: true)
        case .swift:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: swiftKeywords, types: ["Int", "String", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "View", "Binding", "State"], hasDecorators: true)
        case .python:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: pythonKeywords, types: ["int", "str", "float", "bool", "list", "dict", "set", "tuple", "bytes"], isPython: true, hasDecorators: true)
        case .javascript, .typescript:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: jsKeywords, types: ["string", "number", "boolean", "any", "void", "never", "object", "unknown", "Promise"], allowBacktickString: true)
        case .php:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: phpKeywords, types: ["int", "string", "float", "bool", "array", "object", "callable", "iterable"], isPHP: true)
        case .generic:
            highlightCodeLanguage(mutable: mutable, code: code, fullRange: fullRange, baseColor: baseColor, boldFont: boldFont, keywords: genericKeywords, types: [])
        }

        return mutable
    }

    // MARK: - 专用着色通道：Shell / Bash

    private static func highlightShell(mutable: NSMutableAttributedString, code: String, fullRange: NSRange, baseColor: NSColor, boldFont: NSFont) {
        // 1. 注释 #...
        if let regex = RegexCache.hashComment {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            }
        }

        // 2. 双引号/单引号字符串
        if let regex = RegexCache.doubleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
                }
            }
        }
        if let regex = RegexCache.singleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
                }
            }
        }

        // 3. URLs (如 curl 中的目标链接)
        if let regex = RegexCache.url {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemIndigo, range: m.range)
                }
            }
        }

        // 4. 命令标志参数 (-X, -H, --header, -d, -rf, -v 等)
        if let regex = RegexCache.shellFlag {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: m.range)
                    mutable.addAttribute(.font, value: boldFont, range: m.range)
                }
            }
        }

        // 5. 环境变量与参数 ($VAR, ${VAR}, $1)
        if let regex = RegexCache.shellVariable {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }

        // 6. 命令关键字与控制流
        if let regex = RegexCache.identifier {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    let word = (code as NSString).substring(with: m.range).lowercased()
                    if shellCommands.contains(word) {
                        mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: m.range)
                        mutable.addAttribute(.font, value: boldFont, range: m.range)
                    } else if shellKeywords.contains(word) {
                        mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
                        mutable.addAttribute(.font, value: boldFont, range: m.range)
                    }
                }
            }
        }

        // 7. 管道与操作符 (|, &&, ||, >, >>, \)
        if let regex = RegexCache.shellOperator {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
                }
            }
        }

        // 8. 数字
        if let regex = RegexCache.number {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: m.range)
                }
            }
        }
    }

    // MARK: - 专用着色通道：JSON

    private static func highlightJSON(mutable: NSMutableAttributedString, code: String, fullRange: NSRange, boldFont: NSFont) {
        // 键名 ("key":)
        if let regex = RegexCache.jsonKey {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        // 字符串值
        if let regex = RegexCache.doubleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                var isKey = false
                mutable.enumerateAttribute(.foregroundColor, in: m.range, options: []) { val, _, stop in
                    if let color = val as? NSColor, color == NSColor.systemBlue {
                        isKey = true
                        stop.pointee = true
                    }
                }
                if !isKey {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
                }
            }
        }
        // 数字
        if let regex = RegexCache.number {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: m.range)
            }
        }
        // 布尔与空值
        if let regex = RegexCache.identifier {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                let word = (code as NSString).substring(with: m.range).lowercased()
                if word == "true" || word == "false" || word == "null" {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: m.range)
                }
            }
        }
    }

    // MARK: - 专用着色通道：YAML

    private static func highlightYAML(mutable: NSMutableAttributedString, code: String, fullRange: NSRange, boldFont: NSFont) {
        // 注释
        if let regex = RegexCache.hashComment {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            }
        }
        // 键名
        if let regex = RegexCache.yamlKey {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        // 列表破折号 -
        if let regex = RegexCache.yamlBullet {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
            }
        }
        // 字符串
        if let regex = RegexCache.doubleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
            }
        }
        if let regex = RegexCache.singleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
            }
        }
        // 标量字面量与数字
        if let regex = RegexCache.identifier {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                let word = (code as NSString).substring(with: m.range).lowercased()
                if word == "true" || word == "false" || word == "yes" || word == "no" || word == "null" || word == "on" || word == "off" {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: m.range)
                }
            }
        }
        if let regex = RegexCache.number {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: m.range)
            }
        }
    }

    // MARK: - 专用着色通道：Markdown

    private static func highlightMarkdown(mutable: NSMutableAttributedString, code: String, fullRange: NSRange, boldFont: NSFont) {
        // 标题 #
        if let regex = RegexCache.mdHeader {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        // 代码块与行内代码
        if let regex = RegexCache.mdCodeBlock {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBrown, range: m.range)
            }
        }
        // 粗体
        if let regex = RegexCache.mdBold {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        // 列表符
        if let regex = RegexCache.mdList {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
            }
        }
        // 引用块
        if let regex = RegexCache.mdQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            }
        }
        // 链接 [text](url)
        if let regex = RegexCache.mdLink {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemIndigo, range: m.range)
            }
        }
    }

    // MARK: - 专用着色通道：HTML / XML

    private static func highlightHTMLorXML(mutable: NSMutableAttributedString, code: String, fullRange: NSRange, boldFont: NSFont) {
        if let regex = RegexCache.xmlComment {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            }
        }
        if let regex = RegexCache.xmlTag {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        if let regex = RegexCache.xmlAttr {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
            }
        }
        if let regex = RegexCache.doubleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
            }
        }
    }

    // MARK: - 专用着色通道：SQL

    private static func highlightSQL(mutable: NSMutableAttributedString, code: String, fullRange: NSRange, boldFont: NSFont) {
        // 注释
        if let regex = try? NSRegularExpression(pattern: "(?m)(--.*$)|(/\\*[\\s\\S]*?\\*/)", options: []) {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            }
        }
        // 字符串
        if let regex = RegexCache.singleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
            }
        }
        // 数字
        if let regex = RegexCache.number {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: m.range)
            }
        }
        // SQL 关键字
        if let regex = RegexCache.identifier {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                let word = (code as NSString).substring(with: m.range).lowercased()
                if sqlKeywords.contains(word) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
                    mutable.addAttribute(.font, value: boldFont, range: m.range)
                }
            }
        }
    }

    // MARK: - 专用着色通道：CSS

    private static func highlightCSS(mutable: NSMutableAttributedString, code: String, fullRange: NSRange, boldFont: NSFont) {
        if let regex = RegexCache.blockComment {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
            }
        }
        if let regex = RegexCache.cssProp {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        if let regex = RegexCache.cssUnit {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: m.range)
            }
        }
    }

    // MARK: - 通用多语言高亮渲染管道

    private static func highlightCodeLanguage(
        mutable: NSMutableAttributedString,
        code: String,
        fullRange: NSRange,
        baseColor: NSColor,
        boldFont: NSFont,
        keywords: Set<String>,
        types: Set<String>,
        allowBacktickString: Bool = false,
        isRust: Bool = false,
        isCPP: Bool = false,
        isPHP: Bool = false,
        isPython: Bool = false,
        hasDecorators: Bool = false
    ) {
        // 1. 注释
        if isPython {
            if let regex = RegexCache.hashComment {
                for m in regex.matches(in: code, options: [], range: fullRange) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
                }
            }
        } else {
            if let regex = RegexCache.slashComment {
                for m in regex.matches(in: code, options: [], range: fullRange) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
                }
            }
            if let regex = RegexCache.blockComment {
                for m in regex.matches(in: code, options: [], range: fullRange) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
                }
            }
            if isPHP, let regex = RegexCache.hashComment {
                for m in regex.matches(in: code, options: [], range: fullRange) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: m.range)
                }
            }
        }

        // 2. 字符串
        if let regex = RegexCache.doubleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
                }
            }
        }
        if let regex = RegexCache.singleQuote {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
                }
            }
        }
        if allowBacktickString, let regex = RegexCache.backtick {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: m.range)
                }
            }
        }

        // 3. 特殊语言元素
        if isCPP, let regex = RegexCache.cppPreprocessor {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBrown, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        if isRust, let regex = RegexCache.rustMacro {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: m.range)
                mutable.addAttribute(.font, value: boldFont, range: m.range)
            }
        }
        if isPHP {
            if let regex = RegexCache.phpTag {
                for m in regex.matches(in: code, options: [], range: fullRange) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemRed, range: m.range)
                    mutable.addAttribute(.font, value: boldFont, range: m.range)
                }
            }
            if let regex = RegexCache.phpVariable {
                for m in regex.matches(in: code, options: [], range: fullRange) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: m.range)
                }
            }
        }
        if hasDecorators, let regex = RegexCache.decorator {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                mutable.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: m.range)
            }
        }

        // 4. 数字
        if let regex = RegexCache.number {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    mutable.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: m.range)
                }
            }
        }

        // 5. 关键字与类型
        if let regex = RegexCache.identifier {
            for m in regex.matches(in: code, options: [], range: fullRange) {
                if !isRangeColored(mutable: mutable, range: m.range, baseColor: baseColor) {
                    let rawWord = (code as NSString).substring(with: m.range)
                    let lowerWord = rawWord.lowercased()

                    if keywords.contains(lowerWord) || keywords.contains(rawWord) {
                        mutable.addAttribute(.foregroundColor, value: NSColor.systemPink, range: m.range)
                        mutable.addAttribute(.font, value: boldFont, range: m.range)
                    } else if types.contains(rawWord) || types.contains(lowerWord) {
                        mutable.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: m.range)
                        mutable.addAttribute(.font, value: boldFont, range: m.range)
                    } else if commonLiterals.contains(lowerWord) {
                        mutable.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: m.range)
                    }
                }
            }
        }
    }

    // MARK: - 辅助校验方法

    private static func isRangeColored(mutable: NSMutableAttributedString, range: NSRange, baseColor: NSColor) -> Bool {
        var colored = false
        mutable.enumerateAttribute(.foregroundColor, in: range, options: []) { val, _, stop in
            if let color = val as? NSColor, color != baseColor {
                colored = true
                stop.pointee = true
            }
        }
        return colored
    }

    // MARK: - 搜索词高亮

    /// 高亮搜索匹配词
    static func highlightMatches(in attributed: NSAttributedString, tokens: [String]) -> NSAttributedString {
        guard !tokens.isEmpty else { return attributed }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let rawString = (attributed.string as NSString)
        let highlightBg = NSColor.systemYellow.withAlphaComponent(0.35)

        for token in tokens {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            var searchRange = NSRange(location: 0, length: rawString.length)
            while searchRange.location < rawString.length {
                let found = rawString.range(of: trimmed, options: .caseInsensitive, range: searchRange)
                if found.location != NSNotFound {
                    mutable.addAttribute(.backgroundColor, value: highlightBg, range: found)
                    searchRange.location = found.location + found.length
                    searchRange.length = rawString.length - searchRange.location
                } else {
                    break
                }
            }
        }
        return mutable
    }

    /// 将普通文本渲染并高亮搜索匹配词
    static func highlightText(_ text: String, tokens: [String], baseFont: NSFont, baseColor: NSColor) -> NSAttributedString {
        let baseAttr: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor
        ]
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttr)
        return highlightMatches(in: attributed, tokens: tokens)
    }
}
