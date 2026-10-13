// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FlockKit",
    platforms: [
        .iOS("26.0"),
        .macOS(.v15),
    ],
    products: [
        .library(name: "FlockKit", targets: ["FlockKit"]),
    ],
    targets: [
        .target(name: "FlockKit"),
        .testTarget(name: "FlockKitTests", dependencies: ["FlockKit"]),
    ]
)
