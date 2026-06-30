// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Ledge",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                "Core",
                "MediaModule",
                "TimerModule",
                "DropZoneModule",
                "ClipboardModule",
                "SystemModule",
                "ShortcutsModule",
                "CalendarModule",
                "NotesModule",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/App",
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Core",
            path: "Sources/Core",
            resources: [.process("Resources")]
        ),
        .target(
            name: "MediaModule",
            dependencies: ["Core"],
            path: "Sources/Modules/Media",
            linkerSettings: [.linkedFramework("ScriptingBridge")]
        ),
        .target(
            name: "TimerModule",
            dependencies: ["Core"],
            path: "Sources/Modules/Timer"
        ),
        .target(
            name: "DropZoneModule",
            dependencies: ["Core"],
            path: "Sources/Modules/DropZone"
        ),
        .target(
            name: "ClipboardModule",
            dependencies: ["Core"],
            path: "Sources/Modules/Clipboard"
        ),
        .target(
            name: "SystemModule",
            dependencies: ["Core"],
            path: "Sources/Modules/System",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreAudio")]
        ),
        .target(
            name: "ShortcutsModule",
            dependencies: ["Core"],
            path: "Sources/Modules/Shortcuts"
        ),
        .target(
            name: "CalendarModule",
            dependencies: ["Core"],
            path: "Sources/Modules/Calendar"
        ),
        .target(
            name: "NotesModule",
            dependencies: ["Core"],
            path: "Sources/Modules/Notes"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        ),
        .testTarget(
            name: "MediaModuleTests",
            dependencies: ["MediaModule"],
            path: "Tests/MediaModuleTests"
        ),
        .testTarget(
            name: "SystemModuleTests",
            dependencies: ["SystemModule"],
            path: "Tests/SystemModuleTests"
        ),
    ]
)
