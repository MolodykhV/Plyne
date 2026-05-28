// swift-tools-version: 6.0
import PackageDescription

// Pure Swift package: the focus-timer finite state machine. Deterministic,
// clock-injected (no internal Timer), so it builds and tests on Linux.
let package = Package(
    name: "PlyneTimer",
    products: [
        .library(name: "PlyneTimer", targets: ["PlyneTimer"]),
    ],
    dependencies: [
        .package(path: "../PlyneCore"),
    ],
    targets: [
        .target(
            name: "PlyneTimer",
            dependencies: [.product(name: "PlyneCore", package: "PlyneCore")]
        ),
        .testTarget(
            name: "PlyneTimerTests",
            dependencies: ["PlyneTimer"]
        ),
    ]
)
