// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "kvEnvironment",
    platforms: [ .iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6) ],
    products: [
        .library(name: "kvEnvironment", targets: ["kvEnvironment"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Sample",
            dependencies: [
                .target(name: "kvEnvironment"),
            ]
        ),
        .macro(
            name: "kvEnvironmentMacro",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(name: "kvEnvironment", dependencies: [ "kvEnvironmentMacro" ]),
    ]
)
