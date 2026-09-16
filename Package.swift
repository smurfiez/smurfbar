// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Smurfbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Smurfbar",
            path: "Sources/Smurfbar",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
