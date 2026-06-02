// swift-tools-version: 6.2
import PackageDescription

// Pure Swift package: heatmap aggregation, trends, insight-card rules. Same
// Linux-buildable contract as PlyneCore — free of Apple-only frameworks. The
// macOS pin below only constrains Apple platforms (Linux is unaffected) and
// matches the app so Release archives compile with Swift concurrency available.
let package = Package(
    name: "PlyneAnalytics",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "PlyneAnalytics", targets: ["PlyneAnalytics"]),
    ],
    dependencies: [
        .package(path: "../PlyneCore"),
    ],
    targets: [
        .target(
            name: "PlyneAnalytics",
            dependencies: [.product(name: "PlyneCore", package: "PlyneCore")]
        ),
        .testTarget(
            name: "PlyneAnalyticsTests",
            dependencies: ["PlyneAnalytics"]
        ),
    ]
)
