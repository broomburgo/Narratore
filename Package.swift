// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Narratore",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "Narratore",
            targets: ["Narratore"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Narratore",
            dependencies: []),
        .testTarget(
            name: "NarratoreTests",
            dependencies: ["Narratore"]),
    ]
)
