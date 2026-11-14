// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "replay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "replay", targets: ["replay"])
    ],
    targets: [
        .target(name: "Replay Value"),
        .executableTarget(name: "replay", dependencies: ["Replay Value"]),
    ]
)
