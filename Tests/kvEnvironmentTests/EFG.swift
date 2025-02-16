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
//  EFG.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 16.02.2025.
//

@testable import kvEnvironment

// MARK: - E

/// A structure having cyclic dependency on `f`.
///
/// Dependency graph:
/// ```
/// E ═ F
/// ```
struct E {
    let id: String

    @KvEnvironment(\.f) var f
}

extension KvEnvironmentScope { #kvEnvironment { var e: E } }

// MARK: - F

/// A structure having cyclic dependency on `e`.
///
/// Dependency graph:
/// ```
/// E ═ F
/// ```
struct F {
    let id: String

    @KvEnvironment(\.e) var e
}

extension KvEnvironmentScope { #kvEnvironment { var f: F } }

// MARK: - G

/// A structure depending on `e` and `f`.
///
/// Dependency graph:
/// ```
/// E╶─╮
/// ║  G
/// F╶─╯
/// ```
struct G {
    @KvEnvironment(\.e) var e
    @KvEnvironment(\.f) var f
}
