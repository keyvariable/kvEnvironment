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
//  KvEnvironment.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 21.11.2023.
//

// MARK: - KvEnvironmentProtocol

/// This protocol is used to enumerate properties with ``KvEnvironment`` wrapper.
protocol KvEnvironmentProtocol : AnyObject {
    var erasedWrappedValue: Any { get }

    var scope: KvEnvironmentScope? { get set }
}

// MARK: - KvEnvironment

@propertyWrapper
public final class KvEnvironment<Value> : KvEnvironmentProtocol {
    public var scope: KvEnvironmentScope?

    @usableFromInline
    internal let keyPath: KeyPath<KvEnvironmentScope, Value>

    // MARK: Initialization

    @inlinable
    public init(_ keyPath: KeyPath<KvEnvironmentScope, Value>, in scope: KvEnvironmentScope? = nil) {
        self.keyPath = keyPath
        self.scope = scope
    }

    // MARK: + KvEnvironmentProtocol

    var erasedWrappedValue: Any { wrappedValue }

    // MARK: + @propertyWrapper

    @inlinable
    public var wrappedValue: Value { (scope ?? .current)[keyPath: keyPath] }

    @inlinable
    public var projectedValue: KvEnvironment { self }
}
