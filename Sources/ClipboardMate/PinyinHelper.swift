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
        matches(text: text, token: token, pinyinScanLimit: nil)
    }

    /// 列表搜索专用：有限滑动窗口拼音扫描，避免对大段剪贴板反复 CFStringTransform。
    static func matchesForSearch(text: String, token: String) -> Bool {
        matches(text: text, token: token, pinyinScanLimit: -1)
    }

    static func tokenContainsChinese(_ token: String) -> Bool {
        token.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FA5 }
    }

    private static func matches(text: String, token: String, pinyinScanLimit: Int?) -> Bool {
        let lowerText = text.lowercased()
        let lowerToken = token.lowercased()
        if lowerToken.isEmpty { return true }
        if lowerText.contains(lowerToken) { return true }

        let hasChinese = text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FA5 }
        guard hasChinese else { return false }

        if pinyinScanLimit == -1 {
            let windowSize = 800
            let maxWindows = 3
            if text.count <= windowSize {
                let py = pinyin(for: text)
                return py.full.contains(lowerToken) || py.initials.contains(lowerToken)
            }
            var start = text.startIndex
            var windows = 0
            while start < text.endIndex, windows < maxWindows {
                let end = text.index(start, offsetBy: windowSize, limitedBy: text.endIndex) ?? text.endIndex
                let slice = String(text[start..<end])
                let py = pinyin(for: slice)
                if py.full.contains(lowerToken) || py.initials.contains(lowerToken) {
                    return true
                }
                windows += 1
                if end == text.endIndex { break }
                start = end
            }
            return false
        }

        if let pinyinScanLimit, pinyinScanLimit > 0 {
            let capped = text.count <= pinyinScanLimit ? text : String(text.prefix(pinyinScanLimit))
            let py = pinyin(for: capped)
            return py.full.contains(lowerToken) || py.initials.contains(lowerToken)
        }

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
