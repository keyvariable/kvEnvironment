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
//  KvAsyncEnvironmentKey.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 02.03.2025.
//

/// Analog of ``KvEnvironmentKey`` with async provider of default value.
///
/// - SeeAlso: ``kvEnvironment(properties:)``, ``KvEnvironmentScope/subscript(_:)``, ``KvEnvironmentKey``.
public protocol KvAsyncEnvironmentKey : KvEnvironmentKeyProtocol {
    associatedtype Value

    static var defaultValue: Self.Value { get async }
}

public extension KvAsyncEnvironmentKey {
    static var defaultValue: Self.Value { get async { fatalError("No value in the environment for `\(Self.self)` key") } }

    static func defaultProvider() async -> Self.Value { await defaultValue }
}
