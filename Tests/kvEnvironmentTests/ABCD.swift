//===----------------------------------------------------------------------===//
//
//  Copyright (c) 2025 Svyatoslav Popov (info@keyvar.com).
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
//
//  ABCD.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 16.02.2025.
//

@testable import kvEnvironment

// MARK: - A

/// Simple structure with `Int` value.
struct A {
    let value: Int
}

extension KvEnvironmentScope {
    /// - Note: Implicit initial value of optional types is `nil`.
    #kvEnvironment { var a: A? }
}

// MARK: - B

/// Simple structure with `String` value.
class B {
    let value: String

    init(value: String) {
        self.value = value
    }
}

extension KvEnvironmentScope {
    /// A property with explicit default value.
    #kvEnvironment { var b: B = .init(value: "default") }
}

// MARK: - C

/// A class with with `Double` value and two dependencies.
///
/// Dependency graph:
/// ```
/// A╶─╮
///    C
/// B╶─╯
/// ```
class C {
    @KvEnvironment(\.a) var a
    @KvEnvironment(\.b) var b

    let value: Double

    init(value: Double) {
        self.value = value
    }

    /// Replace scope of `b` property only.
    func replace(bScope: KvEnvironmentScope) {
        $b.scope = bScope
    }
}

extension KvEnvironmentScope {
    /// A property having no default value.
    /// - Note: It must be initialized before first use.
    #kvEnvironment { var c: C }
}

// MARK: - D

/// A structure depending on `c`.
///
/// Dependency graph:
/// ```
/// A╶─╮
///    C╶╴D
/// B╶─╯
/// ```
///
/// - Note: It's `Sendable` to provide compile-time test for conformance of `KvEnvironment` to `Sendable` protocol.
struct D: Sendable {
    @KvEnvironment(\.c) var c

    init() { }

    init(scope: KvEnvironmentScope) {
        scope.replace(in: self, options: .recursive)
    }

    /// Replace scope of `c.b` property only.
    func replace(bScope: KvEnvironmentScope) {
        c.replace(bScope: bScope)
    }
}
