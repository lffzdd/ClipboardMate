import Foundation

enum TextTransformer {
    // MARK: - JSON

    static func beautifyJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8) else {
            return nil
        }
        return result
    }

    static func minifyJSON(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let minData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let result = String(data: minData, encoding: .utf8) else {
            return nil
        }
        return result
    }

    // MARK: - Casing

    static func toCamelCase(_ input: String) -> String {
        let words = splitWords(input)
        guard !words.isEmpty else { return input }
        let first = words[0].lowercased()
        let rest = words.dropFirst().map { $0.capitalized }
        return first + rest.joined()
    }

    static func toSnakeCase(_ input: String) -> String {
        let words = splitWords(input)
        guard !words.isEmpty else { return input }
        return words.map { $0.lowercased() }.joined(separator: "_")
    }

    static func toKebabCase(_ input: String) -> String {
        let words = splitWords(input)
        guard !words.isEmpty else { return input }
        return words.map { $0.lowercased() }.joined(separator: "-")
    }

    static func toUpperCase(_ input: String) -> String {
        let words = splitWords(input)
        if words.count > 1 {
            return words.map { $0.uppercased() }.joined(separator: "_")
        }
        return input.uppercased()
    }

    static func toLowerCase(_ input: String) -> String {
        return input.lowercased()
    }

    // MARK: - Encoding & Decoding

    static func urlEncode(_ input: String) -> String {
        return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
    }

    static func urlDecode(_ input: String) -> String {
        return input.removingPercentEncoding ?? input
    }

    static func base64Encode(_ input: String) -> String {
        return input.data(using: .utf8)?.base64EncodedString() ?? input
    }

    static func base64Decode(_ input: String) -> String? {
        guard let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decoded
    }

    // MARK: - Word Segmentation Helper

    static func splitWords(_ input: String) -> [String] {
        var result: [String] = []
        let rawParts = input.components(separatedBy: CharacterSet(charactersIn: "_- \t\r\n"))
        for part in rawParts {
            guard !part.isEmpty else { continue }
            var currentWord = ""
            for char in part {
                if char.isUppercase && !currentWord.isEmpty {
                    result.append(currentWord)
                    currentWord = String(char)
                } else {
                    currentWord.append(char)
                }
            }
            if !currentWord.isEmpty {
                result.append(currentWord)
            }
        }
        return result
    }
}
