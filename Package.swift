// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hover",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Hover",
            path: "Sources/Hover"
        )
    ]
)
