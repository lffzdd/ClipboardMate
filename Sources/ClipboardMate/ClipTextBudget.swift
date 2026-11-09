import Foundation

/// Bounds for list rows, search, language detection, and the side preview.
/// Length checks use UTF-16 (O(1)); never walk the full `String.count` grapheme view.
enum ClipTextBudget {
    /// Characters shown in the side preview for oversized clips.
    static let previewDisplayUTF16 = 16_384
    /// Markdown / syntax highlight / JSON beautify stay on the current 40k-character fuse.
    static let expensiveFormatUTF16 = 40_000
    /// History-row title: collapse newlines only inside this window.
    static let listPreviewUTF16 = 512
    /// Language detection sample. `SourceDocument` splits lines; keep this small.
    static let detectSampleUTF16 = 8_192
    /// `JSONSerialization` of a multi-MB blob on the main thread is a freeze.
    static let jsonParseUTF16 = 65_536
    static let urlMaxUTF16 = 2_048
    static let colorMaxUTF16 = 32

    static func utf16Length(_ text: String) -> Int {
        (text as NSString).length
    }

    static func exceeds(_ text: String, utf16Count: Int) -> Bool {
        utf16Length(text) > utf16Count
    }

    static func isOversizedForPreview(_ text: String) -> Bool {
        exceeds(text, utf16Count: expensiveFormatUTF16)
    }

    static func prefix(_ text: String, utf16Count limit: Int) -> String {
        let ns = text as NSString
        guard ns.length > limit else { return text }
        var end = max(limit, 0)
        if end > 0 {
            let composed = ns.rangeOfComposedCharacterSequence(at: end - 1)
            if NSMaxRange(composed) > end {
                end = composed.location
            }
        }
        return ns.substring(to: max(end, 0))
    }

    static func truncatedPreview(_ text: String) -> String {
        let shown = prefix(text, utf16Count: previewDisplayUTF16)
        guard utf16Length(text) > previewDisplayUTF16 else { return shown }
        return shown + "\n…"
    }

    /// Byte scan for `\n` — no `components(separatedBy:)` array of substrings.
    static func lineCount(_ text: String) -> Int {
        var count = 1
        for byte in text.utf8 where byte == 0x0A {
            count += 1
        }
        return count
    }

    /// `{…}` / `[…]` after ASCII whitespace at the edges. Does not parse JSON.
    static func looksLikeJSONContainer(_ text: String) -> Bool {
        let bytes = text.utf8
        var start = bytes.startIndex
        let end = bytes.endIndex
        while start < end, isASCIIWhitespace(bytes[start]) {
            start = bytes.index(after: start)
        }
        guard start < end else { return false }
        var last = bytes.index(before: end)
        while last > start, isASCIIWhitespace(bytes[last]) {
            last = bytes.index(before: last)
        }
        let first = bytes[start]
        let lastByte = bytes[last]
        return (first == 123 && lastByte == 125) || (first == 91 && lastByte == 93)
    }

    private static func isASCIIWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }
}
