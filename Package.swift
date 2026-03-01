// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LightroomShareHelper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LightroomShareHelper", targets: ["LightroomShareHelper"])
    ],
    targets: [
        .executableTarget(
            name: "LightroomShareHelper"
        )
    ]
)
