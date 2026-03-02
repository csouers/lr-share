// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LightroomClipboardHelper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LightroomClipboardHelper", targets: ["LightroomClipboardHelper"])
    ],
    targets: [
        .executableTarget(
            name: "LightroomClipboardHelper"
        )
    ]
)