import AppKit
import Foundation

struct ClipItem: Codable {
    enum Kind: String, Codable {
        case text
        case image
        case file
    }

    var id = UUID()
    var kind: Kind
    var text: String?
    var html: String? = nil
    var rtf: Data? = nil
    var imageFile: String?
    var width: Int?
    var height: Int?
    var filePaths: [String]? = nil
    var createdAt: Date
    var pinned: Bool = false
    var ocrText: String?
    var alias: String?
    var sourceAppName: String? = nil
    var sourceAppBundleId: String? = nil

    var fileCount: Int {
        filePaths?.count ?? 0
    }

    var firstFilePath: String? {
        filePaths?.first
    }

    var existingFilePaths: [String] {
        (filePaths ?? []).filter { FileManager.default.fileExists(atPath: $0) }
    }

    var hasMissingFiles: Bool {
        guard kind == .file, let paths = filePaths, !paths.isEmpty else { return false }
        return paths.contains { !FileManager.default.fileExists(atPath: $0) }
    }

    var allFilesMissing: Bool {
        guard kind == .file, let paths = filePaths, !paths.isEmpty else { return false }
        return paths.allSatisfy { !FileManager.default.fileExists(atPath: $0) }
    }

    var fileTotalSizeFormatted: String {
        guard let paths = filePaths, !paths.isEmpty else { return "" }
        var totalBytes: Int64 = 0
        for p in paths {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: p),
               let size = attrs[.size] as? Int64 {
                totalBytes += size
            }
        }
        let countStr = paths.count == 1 ? "" : "\(L10n.fileCountShort(paths.count)) • "
        if totalBytes > 1024 * 1024 * 1024 {
            return String(format: "%@%.1f GB", countStr, Double(totalBytes) / (1024.0 * 1024.0 * 1024.0))
        } else if totalBytes > 1024 * 1024 {
            return String(format: "%@%.1f MB", countStr, Double(totalBytes) / (1024.0 * 1024.0))
        } else if totalBytes > 1024 {
            return String(format: "%@%.1f KB", countStr, Double(totalBytes) / 1024.0)
        } else if totalBytes > 0 {
            return String(format: "%@%lld B", countStr, totalBytes)
        }
        return paths.count == 1 ? "" : L10n.fileCountShort(paths.count)
    }

    var previewText: String {
        if kind == .file {
            guard let paths = filePaths, !paths.isEmpty else { return "" }
            if paths.count == 1 {
                return URL(fileURLWithPath: paths[0]).lastPathComponent
            } else if paths.count == 2 {
                return paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
            } else {
                let firstTwo = paths.prefix(2).map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
                return "\(firstTwo) \(L10n.fileAndMore(paths.count))"
            }
        }
        guard kind == .text, let text else { return "" }
        let oneLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if oneLine.count > 120 {
            return String(oneLine.prefix(120)) + "…"
        }
        return oneLine
    }

    var displayTitle: String {
        if let alias = alias, !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return alias.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return previewText
    }

    var isURL: Bool {
        guard kind == .text, let str = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return (str.hasPrefix("http://") || str.hasPrefix("https://")) && URL(string: str) != nil
    }

    var colorValue: NSColor? {
        guard kind == .text, let str = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        guard str.hasPrefix("#") else { return nil }
        var hex = String(str.dropFirst())
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        var intVal: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&intVal) else { return nil }
        if hex.count == 6 {
            let r = CGFloat((intVal >> 16) & 0xFF) / 255.0
            let g = CGFloat((intVal >> 8) & 0xFF) / 255.0
            let b = CGFloat(intVal & 0xFF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
        } else if hex.count == 8 {
            let r = CGFloat((intVal >> 24) & 0xFF) / 255.0
            let g = CGFloat((intVal >> 16) & 0xFF) / 255.0
            let b = CGFloat((intVal >> 8) & 0xFF) / 255.0
            let a = CGFloat(intVal & 0xFF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        }
        return nil
    }

    var isColor: Bool { colorValue != nil }

    var colorRGBString: String? {
        guard let color = colorValue?.usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(color.redComponent * 255))
        let g = Int(round(color.greenComponent * 255))
        let b = Int(round(color.blueComponent * 255))
        if color.alphaComponent < 1.0 {
            return String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, color.alphaComponent)
        }
        return "rgb(\(r), \(g), \(b))"
    }

    var colorHSLString: String? {
        guard let color = colorValue?.usingColorSpace(.sRGB) else { return nil }
        let r = color.redComponent
        let g = color.greenComponent
        let b = color.blueComponent

        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal

        var h: CGFloat = 0
        var s: CGFloat = 0
        let l = (maxVal + minVal) / 2.0

        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - maxVal - minVal) : delta / (maxVal + minVal)
            if maxVal == r {
                h = ((g - b) / delta) + (g < b ? 6.0 : 0.0)
            } else if maxVal == g {
                h = ((b - r) / delta) + 2.0
            } else {
                h = ((r - g) / delta) + 4.0
            }
            h /= 6.0
        }

        let hDeg = Int(round(h * 360))
        let sPct = Int(round(s * 100))
        let lPct = Int(round(l * 100))
        return "hsl(\(hDeg)°, \(sPct)%, \(lPct)%)"
    }

    var urlHost: String? {
        guard isURL, let str = text?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: str) else { return nil }
        return url.host
    }

    var lineCount: Int {
        guard kind == .text, let text else { return 0 }
        return text.components(separatedBy: "\n").count
    }

    var characterCount: Int {
        guard kind == .text, let text else { return 0 }
        return text.count
    }
}
