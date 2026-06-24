// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Bodega",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "Bodega",
            targets: ["Bodega"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto", from: Version(3, 9, 1)),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: Version(0, 13, 2)),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Bodega",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            swiftSettings: [
                .define("ENABLE_TESTABILITY", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "BodegaTests",
            dependencies: ["Bodega"]
        ),
    ]
)
