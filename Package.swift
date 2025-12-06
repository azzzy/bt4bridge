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
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreMIDI"),
            ]
        )
    ]
)