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
        .library(
            name: "OpenMarkedCore",
            targets: ["OpenMarkedCore"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OpenMarkedApp",
            dependencies: ["OpenMarkedCore"]
        ),
        .target(
            name: "OpenMarkedCore"
        ),
        .executableTarget(
            name: "OpenMarkedVerifier",
            dependencies: ["OpenMarkedCore"]
        ),
        .testTarget(
            name: "OpenMarkedCoreTests",
            dependencies: ["OpenMarkedCore"]
        )
    ]
)
