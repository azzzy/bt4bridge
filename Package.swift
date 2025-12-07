// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bt4bridge",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "BT4BridgeCore",
            targets: ["BT4BridgeCore"]
        )
    ],
    dependencies: [],
    targets: [
        // Core bridge library (shared between CLI and GUI app)
        .target(
            name: "BT4BridgeCore",
            dependencies: [],
            path: "Sources/bt4bridge",
            swiftSettings: [],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreMIDI"),
            ]
        ),
        // CLI executable
        .executableTarget(
            name: "bt4bridge",
            dependencies: ["BT4BridgeCore"],
            path: "Sources/bt4bridge-cli",
            swiftSettings: [],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreMIDI"),
            ]
        ),
        // Menu bar app executable
        .executableTarget(
            name: "bt4bridge-app",
            dependencies: ["BT4BridgeCore"],
            path: "Sources/bt4bridge-app",
            resources: [.process("Resources")],
            swiftSettings: [],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreMIDI"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        // Simulators and testers
        .executableTarget(
            name: "pg4simulator",
            dependencies: [],
            swiftSettings: [],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
            ]
        ),
        .executableTarget(
            name: "ledtester",
            dependencies: [],
            swiftSettings: [],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
            ]
        ),
        // Tests
        .testTarget(
            name: "bt4bridgeTests",
            dependencies: ["BT4BridgeCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)