//===----------------------------------------------------------------------===//
//
//  Copyright (c) 2024 Svyatoslav Popov (info@keyvar.com).
//
//  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
//  License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
//  later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
//  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with this program.
//  If not, see <https://www.gnu.org/licenses/>.
//
//  SPDX-License-Identifier: GPL-3.0-or-later
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

    private static let mutationLock = NSLock()

    public private(set) var parent: KvEnvironmentScope?

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
        get { value(forKey: key) ?? key.defaultValue }
        set { withLock { container[ObjectIdentifier(key)] = newValue } }
    }

    @usableFromInline
    internal func value<Key : KvEnvironmentKey>(forKey key: Key.Type) -> Key.Value? {
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

        var container = self

        while let next = container.parent {
            if let value = next.withLock({ block(next) }) {
                return value
            }

            container = next
        }

        return nil
    }

    // MARK: + NSLocking

    @inlinable public func lock() { mutationLock.lock() }

    @inlinable public func unlock() { mutationLock.unlock() }

    // MARK: Static Locking

    private static func withLock<R>(_ body: () throws -> R) rethrows -> R {
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
