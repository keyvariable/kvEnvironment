//===----------------------------------------------------------------------===//
//
//  Copyright (c) 2023 Svyatoslav Popov (info@keyvar.com).
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
//  KvEnvironmentKey.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 22.11.2023.
//

/// Types adopting `KvEnvironmentKey` protocol identify environment properties in scopes (``KvEnvironmentScope``).
/// An environment key defines the value type and optionally provides default value.
///
/// Usually there is no need to define keys manually.
/// ``kvEnvironment(properties:)`` macro defines both keys and convenient properties in scopes.
///
/// - SeeAlso: ``kvEnvironment(properties:)``, ``KvEnvironmentScope/subscript(_:)``.
public protocol KvEnvironmentKey {
    associatedtype Value

    static var defaultValue: Self.Value { get }
}

public extension KvEnvironmentKey {
    static var defaultValue: Self.Value { fatalError("No value in the environment for `\(Self.self)` key") }
}
