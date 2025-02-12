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

/// This property wrapper helps to create references to properties in environment scopes (``KvEnvironmentScope``).
/// Let `serviceA` of type `ServiceA` is an environment property.
/// Then a dependency in another service `ServiceB` may be declared this way:
/// ```swift
/// struct ServiceB {
///     @KvEnvironment(\.serviceA) private var serviceA
/// }
/// ```
///
/// Type of `serviceA` is inferred.
///
/// `KvEnvironment` doesn't store a direct reference to an instance.
/// It stores a key path and resolves it in ``KvEnvironmentScope/current`` task-local scope each time.
/// So retain cycles don't occur in cyclic dependencies.
/// Scope can be specified explicitly when `KvEnvironment` initialized or via ``scope`` property of projected value (`$serviceA.scope`) at run time.
/// Also ``KvEnvironmentScope/replace(in:options:)-4j9gb`` and it's overloads may be used.
///
/// It isn't required to use `KvEnvironment` to access environment properties.
/// You can access properties via ``KvEnvironmentScope/subscript(key:)`` by it key or via shorthand property if available.
/// See ``kvEnvironment(properties:)`` macro. This macro creates both the keys and the properties.
/// It's convenient when you need to save an instance regardless to any further changes in environment.
/// Below is an example where `serviceA` is saved from global scope when `ServiceC` is initialized:
/// ```swift
/// struct ServiceC {
///     let serviceA = KvEnvironmentScope.global.serviceA
/// }
/// ```
///
/// - SeeAlso: ``KvEnvironmentScope``.
@propertyWrapper
public final class KvEnvironment<Value> : KvEnvironmentProtocol {
    /// A scope the receiver is resolved in.
    /// If it's `nil` (default) then the receiver is resolved in ``KvEnvironmentScope/current`` task-local scope.
    ///
    /// - Note: This property is not thread-safe.
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
