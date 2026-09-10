// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OllamaBridge",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OllamaBridge",
            path: "Sources/OllamaBridge"
        )
    ]
)
