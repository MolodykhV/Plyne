// swift-tools-version: 6.2
import PackageDescription

// Pure Swift package: the focus-timer finite state machine. Deterministic,
// clock-injected (no internal Timer), so it builds and tests on Linux. The
// macOS pin below only constrains Apple platforms (Linux is unaffected) and
// matches the app so Release archives compile with Swift concurrency available.
let package = Package(
    name: "PlyneTimer",
    platforms: [
        .macOS(.v26),
    ],
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
