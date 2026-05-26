// swift-tools-version: 6.2
import PackageDescription

// macOS-only: SwiftData schema, repositories, persistence wiring.
// Apple-framework dependent, so we pin the platform and skip Linux CI here.
let package = Package(
    name: "PlyneStorage",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "PlyneStorage", targets: ["PlyneStorage"]),
    ],
    dependencies: [
        .package(path: "../PlyneCore"),
    ],
    targets: [
        .target(
            name: "PlyneStorage",
            dependencies: [.product(name: "PlyneCore", package: "PlyneCore")]
        ),
        .testTarget(
            name: "PlyneStorageTests",
            dependencies: ["PlyneStorage"]
        ),
    ]
)
