// swift-tools-version: 6.0
import PackageDescription

// Pure Swift package: domain types, timer FSM, math.
// Intentionally NO platform restriction — this package must build and test
// on Linux in CI to keep iteration cheap.
let package = Package(
    name: "PlyneCore",
    products: [
        .library(name: "PlyneCore", targets: ["PlyneCore"]),
    ],
    targets: [
        .target(name: "PlyneCore"),
        .testTarget(name: "PlyneCoreTests", dependencies: ["PlyneCore"]),
    ]
)
