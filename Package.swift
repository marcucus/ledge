// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Notchy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["Core", "MediaModule"],
            path: "Sources/App",
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .target(
            name: "MediaModule",
            dependencies: ["Core"],
            path: "Sources/Modules/Media"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        ),
    ]
)
