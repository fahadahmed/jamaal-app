// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JamaalCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "JamaalCore",
            targets: ["JamaalCore"]
        ),
    ],
    dependencies: [
        // Prayer times, computed on-device (MIT). Confined to `PrayerWindows.swift`.
        .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "JamaalCore",
            dependencies: [.product(name: "Adhan", package: "adhan-swift")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "JamaalCoreTests",
            dependencies: ["JamaalCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
