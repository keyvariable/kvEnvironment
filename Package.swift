// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "kvEnvironment",
    platforms: [ .iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6) ],
    products: [
        .library(name: "kvEnvironment", targets: ["kvEnvironment"]),
    ],
    targets: [
        .target(name: "kvEnvironment"),
        .executableTarget(
            name: "Sample",
            dependencies: [
                .target(name: "kvEnvironment"),
            ]
        ),
    ]
)
