// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardMate",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ClipboardMate", path: "Sources/ClipboardMate")
    ]
)
