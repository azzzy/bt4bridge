// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bt4bridge",
    platforms: [.macOS(.v12)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "bt4bridge",
            dependencies: [],
            swiftSettings: [],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreMIDI"),
            ]
        ),
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
        .testTarget(
            name: "bt4bridgeTests",
            dependencies: ["bt4bridge"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)