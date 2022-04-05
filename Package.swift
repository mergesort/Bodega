// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Bodega",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "Bodega",
            targets: ["Bodega"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Bodega",
            dependencies: []),
        .testTarget(
            name: "BodegaTests",
            dependencies: ["Bodega"]),
    ]
)
