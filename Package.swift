// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenMarked",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OpenMarked",
            targets: ["OpenMarkedApp"]
        ),
        .executable(
            name: "OpenMarkedVerifier",
            targets: ["OpenMarkedVerifier"]
        ),
        .executable(
            name: "OpenMarkedSnapshotter",
            targets: ["OpenMarkedSnapshotter"]
        ),
        .library(
            name: "OpenMarkedCore",
            targets: ["OpenMarkedCore"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenMarkedApp",
            dependencies: ["OpenMarkedCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "OpenMarkedCore",
            dependencies: ["CMarkdownGFM"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "CMarkdownGFM",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("cmark-gfm")
            ]
        ),
        .executableTarget(
            name: "OpenMarkedVerifier",
            dependencies: ["OpenMarkedCore"]
        ),
        .executableTarget(
            name: "OpenMarkedSnapshotter",
            dependencies: ["OpenMarkedCore"]
        ),
        .testTarget(
            name: "OpenMarkedCoreTests",
            dependencies: ["OpenMarkedCore"]
        ),
        .testTarget(
            name: "OpenMarkedAppTests",
            dependencies: ["OpenMarkedApp", "OpenMarkedCore"]
        )
    ]
)
