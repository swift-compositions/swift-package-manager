// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-package-manager",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Package Manager", targets: ["Package Manager"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-standards/swift-fips-180-4.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-standards/swift-spm-standard.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-file-system.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-json.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-process.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Package Manager",
            dependencies: [
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "SPM Standard", package: "swift-spm-standard"),
                .product(name: "File System", package: "swift-file-system"),
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Process", package: "swift-process"),
            ]
        ),
        .testTarget(
            name: "Package Manager Tests",
            dependencies: ["Package Manager"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        ]
}
