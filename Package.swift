// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Narratore",
  platforms: [.iOS(.v13), .macOS(.v14)],
  products: [
    .library(
      name: "Narratore",
      targets: ["Narratore"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Narratore",
      dependencies: [],
      swiftSettings: [
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
      ]
    ),
    .testTarget(
      name: "NarratoreTests",
      dependencies: ["Narratore"],
      swiftSettings: [
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
      ]
    ),
  ]
)
