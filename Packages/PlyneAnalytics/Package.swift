// swift-tools-version: 6.0
import PackageDescription

// Pure Swift package: heatmap aggregation, trends, insight-card rules.
// Same Linux-buildable contract as PlyneCore — keep it free of Apple-only
// frameworks so it stays cheap to test.
let package = Package(
    name: "PlyneAnalytics",
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
