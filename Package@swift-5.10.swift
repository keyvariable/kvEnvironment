// swift-tools-version: 5.10
//
//===----------------------------------------------------------------------===//
//
//  Copyright (c) 2024 Svyatoslav Popov (info@keyvar.com).
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with
//  the License. You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
//  an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
//  specific language governing permissions and limitations under the License.
//
//  SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
        .macro(
            name: "kvEnvironmentMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(name: "kvEnvironment", dependencies: [ "kvEnvironmentMacros" ]),
        .testTarget(
            name: "kvEnvironmentTests",
            dependencies: ["kvEnvironment"]
        ),
    ]
)
