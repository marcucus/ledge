// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Notchy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["Core"],
            path: "Sources/App",
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        ),
    ]
)
