// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TVControl",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TVControl", path: "Sources/TVControl"),
    ]
)
