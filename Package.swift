// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaptureFlow",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    targets: [
        // Naming brain CLI — test slugs against any image
        .executableTarget(
            name: "sst",
            dependencies: ["CaptureFlowCore"],
            path: "Sources/CLI"
        ),
        // Background daemon — watches screenshot folder and renames automatically
        .executableTarget(
            name: "ssd",
            dependencies: ["CaptureFlowCore"],
            path: "Sources/Daemon"
        ),
        // Menu bar app — NSStatusItem with enable/disable, preferences, launch at login
        .executableTarget(
            name: "CaptureFlow",
            dependencies: ["CaptureFlowCore"],
            path: "Sources/App",
            resources: [.process("Resources")]
        ),
        // Shared library — all naming tiers, daemon types, slug logic
        .target(
            name: "CaptureFlowCore",
            path: "Sources/Core"
        ),
        // Tests
        .testTarget(
            name: "CaptureFlowTests",
            dependencies: ["CaptureFlowCore"],
            path: "Tests"
        )
    ]
)
