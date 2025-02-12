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
//
//  KvEnvironmentScope.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 23.12.2024.
//

import Foundation

// TODO: DOC
public final class KvEnvironmentScope : NSLocking {
    public static var global: KvEnvironmentScope {
        get { withLock { _global } }
        set { withLock { _global = newValue } }
    }

    public static var current: KvEnvironmentScope { .taskLocal ?? .global }

    @TaskLocal
    static var taskLocal: KvEnvironmentScope?

    private static var _global = KvEnvironmentScope(parent: nil)

    // - NOTE: Recursive lock is used to provide consistent public interface and avoid dead locks when `lock()` and `unlock()` are used.
    private static let mutationLock = NSRecursiveLock()

    public var parent: KvEnvironmentScope? {
        get { withLock { _parent } }
        set { withLock { _parent = newValue } }
    }

    @usableFromInline
    internal var _parent: KvEnvironmentScope?

    @usableFromInline
    internal var container: [ObjectIdentifier : Any] = .init()

    @usableFromInline
    internal let mutationLock = NSLock()

    // MARK: Initialization

    // TODO: DOC
    @usableFromInline
    internal init(parent: KvEnvironmentScope? = .global) {
        self.parent = parent
    }

    // TODO: DOC
    /// - SeeAlso: ``empty(parent:)``.
    public convenience init(parent: KvEnvironmentScope? = .global, contentBlock: (borrowing KvEnvironmentScope) -> Void) {
        self.init(parent: parent)

        self.callAsFunction(body: contentBlock)
    }

    // TODO: DOC
    @inlinable
    public static func empty(parent: KvEnvironmentScope? = .global) -> KvEnvironmentScope {
        .init(parent: parent)
    }

    // MARK: Content

    var isEmpty: Bool {
        withLock {
            container.isEmpty
        }
    }

    func forEach(_ body: (Any) -> Void) {
        withLock { container }
            .values.forEach(body)
    }

    /// Getter returns the closest value in the hierarchy by given *key*.
    /// ``KvEnvironmentKey/defaultValue`` is returned if there is no value for *key*.
    @inlinable
    public subscript<Key : KvEnvironmentKey>(key: Key.Type) -> Key.Value {
        get { value(forKey: key) }
        set { withLock { container[ObjectIdentifier(key)] = newValue } }
    }

    /// Removes value for given *key* from the receiver.
    ///
    /// - Returns: Removed value.
    ///
    /// - Note: This method is thread-safe.
    ///
    /// - SeeAlso: ``subscript(key:)``.
    @inlinable
    public func removeValue<Key : KvEnvironmentKey>(forKey key: Key.Type) -> Key.Value? {
        withLock {
            container.removeValue(forKey: ObjectIdentifier(key))
                .map { $0 as! Key.Value }
        }
    }

    @usableFromInline
    internal func value<Key : KvEnvironmentKey>(forKey key: Key.Type) -> Key.Value {
        lock()
        defer { unlock() }

        return firstResult { scope in scope.container[ObjectIdentifier(key)] }
            .map { $0 as! Key.Value }
        ?? { value in
            container[ObjectIdentifier(key)] = value
            return value
        }(key.defaultValue)
    }

    /// - Important: The receiver must be locked.
    private func firstResult<T>(of block: (borrowing KvEnvironmentScope) -> T?) -> T? {
        if let value = block(self) {
            return value
        }

        var next = _parent

        while let container = next {
            if let value = container.withLock({ block(container) }) {
                return value
            }

            next = container.parent
        }

        return nil
    }

    // MARK: + NSLocking

    /// - SeeAlso: ``withLock(_:)-swift.method``, ``unlock()-swift.method``.
    @inlinable public func lock() { mutationLock.lock() }

    /// - SeeAlso: ``withLock(_:)-swift.method``, ``lock()-swift.method``.
    @inlinable public func unlock() { mutationLock.unlock() }

    // MARK: Static Locking

    /// - SeeAlso: ``withLock(_:)-swift.type.method(_:)``, ``unlock()-swift.type.method``.
    public static func lock() { mutationLock.lock() }

    /// - SeeAlso: ``withLock(_:)-swift.type.method``, ``lock()-swift.type.method``.
    public static func unlock() { mutationLock.unlock() }

    /// - SeeAlso: ``lock()-swift.type.method``, ``unlock()-swift.type.method``.
    public static func withLock<R>(_ body: () throws -> R) rethrows -> R {
        try mutationLock.withLock(body)
    }

    // MARK: Operations

    // TODO: DOC
    @KvEnvironmentScopeAsyncThrowsOverloads
    public func callAsFunction(body: () -> Void) {
        KvEnvironmentScope.$taskLocal.withValue(self, operation: body)
    }

    // TODO: DOC
    @KvEnvironmentScopeAsyncThrowsOverloads
    public func callAsFunction(body: (borrowing KvEnvironmentScope) -> Void) {
        KvEnvironmentScope.$taskLocal.withValue(self) {
            body(self)
        }
    }

    // TODO: DOC
    @inlinable
    public func replace(in instance: Any, options: ReplaceOptions = []) {
        switch options.contains(.recursive) {
        case false:
            _replace(in: instance)

        case true:
            var visitedIDs = Set<ObjectIdentifier>()

            _replace(in: instance, options: options, visitedIDs: &visitedIDs)
        }
    }

    // TODO: DOC
    @inlinable
    public func replace<I>(in instances: I, options: ReplaceOptions = []) where I: Sequence {
        var visitedIDs = Set<ObjectIdentifier>()

        instances.forEach {
            _replace(in: $0, options: options, visitedIDs: &visitedIDs)
        }
    }

    // TODO: DOC
    @inlinable
    public func replace(in first: Any, _ second: Any, _ rest: Any..., options: ReplaceOptions = []) {
        var visitedIDs = Set<ObjectIdentifier>()

        _replace(in: first, options: options, visitedIDs: &visitedIDs)
        _replace(in: second, options: options, visitedIDs: &visitedIDs)

        rest.forEach {
            _replace(in: $0, options: options, visitedIDs: &visitedIDs)
        }
    }

    @usableFromInline
    internal func _replace(in instance: Any) {
        Mirror(reflecting: instance).children.forEach {
            guard let reference = $0.value as? KvEnvironmentProtocol else { return }

            reference.scope = self
        }
    }

    @usableFromInline
    internal func _replace(in instance: Any, options: ReplaceOptions, visitedIDs: inout Set<ObjectIdentifier>) {
        switch options.contains(.recursive) {
        case false:
            Mirror(reflecting: instance).children.forEach {
                guard let reference = $0.value as? KvEnvironmentProtocol,
                      visitedIDs.insert(ObjectIdentifier(reference)).inserted
                else { return }

                reference.scope = self
            }

        case true:
            // Recursively enumerating properties wrapped with `@KvEnvironment`.
            //
            // - NOTE: For-in cycle is used to reduce depth of recursion.
            for property in Mirror(reflecting: instance).children {
                guard let reference = property.value as? KvEnvironmentProtocol,
                      visitedIDs.insert(ObjectIdentifier(reference)).inserted
                else { continue }

                reference.scope = self

                _replace(in: reference.erasedWrappedValue, options: options, visitedIDs: &visitedIDs)
            }
        }
    }

    // MARK: .ReplaceOptions

    public struct ReplaceOptions: OptionSet, ExpressibleByIntegerLiteral {
        @inlinable public static var recursive: ReplaceOptions { 0x01 }

        // MARK: + OptionSet

        public typealias RawValue = UInt8

        public let rawValue: RawValue

        @inlinable public init(rawValue: RawValue) { self.rawValue = rawValue }

        // MARK: + ExpressibleByIntegerLiteral

        @inlinable public init(integerLiteral value: IntegerLiteralType) { self.init(rawValue: numericCast(value)) }
    }
}

// MARK: - macro kvEnvironmentScope

// TODO: DOC
@freestanding(declaration, names: arbitrary)
public macro kvEnvironment(properties: () -> Void) = #externalMacro(module: "kvEnvironmentMacros", type: "KvEnvironmentScopeEntryMacro")

// MARK: - macro KvEnvironmentScopeOverloads

/// This macro creates overloads of a function having `async`, `throws` and `async throws` effects on the method and any closure parameter.
@attached(peer, names: overloaded)
private macro KvEnvironmentScopeAsyncThrowsOverloads() = #externalMacro(
    module: "kvEnvironmentMacros",
    type: "KvEnvironmentScopeAsyncThrowsOverloadsMacro"
)
