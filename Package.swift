// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Smurfbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Smurfbar",
            path: "Sources/Smurfbar"
        )
    ]
)
