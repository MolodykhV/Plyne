// swift-tools-version: 6.2
import PackageDescription

// Pure Swift package: domain types, timer FSM, math. Still builds and tests on
// Linux in CI — the macOS floor below only constrains Apple platforms, not Linux.
// The pin matches the app so Release archives compile with Swift concurrency
// available (an unpinned package defaults to an SDK floor where async is absent).
let package = Package(
    name: "PlyneCore",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(name: "PlyneCore", targets: ["PlyneCore"]),
    ],
    targets: [
        .target(name: "PlyneCore"),
        .testTarget(name: "PlyneCoreTests", dependencies: ["PlyneCore"]),
    ]
)
