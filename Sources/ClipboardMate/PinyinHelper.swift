import Foundation

final class PinyinResult: NSObject {
    let full: String
    let initials: String

    init(full: String, initials: String) {
        self.full = full
        self.initials = initials
    }
}

enum PinyinHelper {
    private static let cache: NSCache<NSString, PinyinResult> = {
        let cache = NSCache<NSString, PinyinResult>()
        cache.countLimit = 400
        return cache
    }()

    static func pinyin(for text: String) -> PinyinResult {
        let key = text as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let mutable = NSMutableString(string: text) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let latin = (mutable as String).lowercased()

        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let words = latin.components(separatedBy: separators).filter { !$0.isEmpty }

        let full = words.joined()
        let initials = String(words.compactMap { $0.first })

        let result = PinyinResult(full: full, initials: initials)
        cache.setObject(result, forKey: key)
        return result
    }

    /// 检查 text 是否包含 token（原词包含、全拼包含、首字母包含）
    static func matches(text: String, token: String) -> Bool {
        let lowerText = text.lowercased()
        let lowerToken = token.lowercased()
        if lowerToken.isEmpty { return true }
        if lowerText.contains(lowerToken) { return true }

        let hasChinese = text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FA5 }
        guard hasChinese else { return false }

        let windowSize = 240
        let step = 180
        if text.count <= windowSize {
            let py = pinyin(for: text)
            return py.full.contains(lowerToken) || py.initials.contains(lowerToken)
        }

        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: windowSize, limitedBy: text.endIndex) ?? text.endIndex
            let py = pinyin(for: String(text[start..<end]))
            if py.full.contains(lowerToken) || py.initials.contains(lowerToken) {
                return true
            }
            if end == text.endIndex { break }
            start = text.index(start, offsetBy: step, limitedBy: text.endIndex) ?? text.endIndex
        }
        return false
    }
}
