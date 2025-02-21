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

/// Scopes store environment properties and provide access to them via keys.
///
/// Keys are represented as types adopting ``KvEnvironmentKey`` protocol.
/// Keys provide strong typing and default values.
/// Default values are lazily evaluated once when a scope contains no value for a key.
///
/// Below is an example of an environment property `serviceA` of `ServiceA` type with default initializer:
/// ```swift
/// extension KvEnvironmentScope {
///     #kvEnvironment { var serviceA: ServiceA = .init() }
/// }
/// ```
/// ``kvEnvironment(properties:)`` macro is a simple way to declare environment properties.
/// With this macro environment properties are declared just like usual properties with type annotations and initial values.
/// Also environment keys are created automatically.
/// Below is an example of explicit declaration of key and convenient property:
/// ```swift
/// extension KvEnvironmentScope {
///     private struct ServiceAKey : KvEnvironmentKey {
///         static var defaultValue: ServiceA { .init() }
///     }
///     var serviceA: ServiceA {
///         get { self[ServiceAKey.self] }
///         set { self[ServiceAKey.self] = newValue }
///     }
/// }
/// ```
///
/// Scopes can be nested to compose complex hierarchies.
/// See ``parent`` property.
///
/// Access to values is provided via ``subscript(_:)`` subscript.
/// It can be used explicitly or implicitly via convenient ``KvEnvironment`` property wrapper.
/// See examples:
/// ```swift
/// struct B1 {
///     @KvEnvironment(\.serviceA) private var serviceA
/// }
/// struct B2 {
///     private let serviceA: ServiceA
///
///     init(_ scope: KvEnvironmentScope = .current) {
///         serviceA = scope.serviceA
///     }
/// }
/// struct B3 {
///     private let serviceA = KvEnvironmentScope.current[ServiceAKey.self]
/// }
/// ```
///
/// Both instance and static methods of `KvEnvironmentScope` are thread-safe.
///
/// ## Global and Current Scopes
///
/// `KvEnvironmentScope` provides ``global`` scope.
/// It always exists and is used when no other scope is provided.
/// Global scope is mutable so it can be replaced with your own instance.
/// Also a scope (``global`` among others) can be modified via ``callAsFunction(body:)-90rzi`` syntax:
/// ```swift
/// KvEnvironmentScope.global {
///     $0.serviceA = someInstance
/// }
/// ```
///
/// `KvEnvironmentScope` also provides ``current`` scope.
/// It's tail of a task-local (thread-local in synchronous context) scope stack
/// where head is ``global`` scope and elements are temporary pushed via ``callAsFunction(body:)-4envx`` syntax.
/// ``KvEnvironment`` property wrapper resolves references in ``current`` scope by default.
/// For example:
/// ```swift
/// struct C {
///     @KvEnvironment(\.serviceA) private var serviceA
/// }
///
/// let customScope = KvEnvironmentScope {
///     $0.serviceA = otherInstance
/// }
/// let c = C()
///
/// // Value of c.serviceA is from global scope here
/// print(c.serviceA)
///
/// customScope {
///     // Value of c.serviceA is from customScope here
///     print(c.serviceA)
/// }
/// ```
///
/// - SeeAlso: ``KvEnvironment``, ``kvEnvironment(properties:)``, ``KvEnvironmentKey``.
public final class KvEnvironmentScope : NSLocking, @unchecked Sendable {
    /// The global scope.
    /// It's used as default parent scope and it's default ``current`` scope.
    ///
    /// It can be changed. Access to this property is thread-safe.
    ///
    /// - SeeAlso: ``current``, ``withLock(_:)-swift.type.method``.
    public static var global: KvEnvironmentScope {
        get { withLock { _global } }
        set { withLock { _global = newValue } }
    }

    /// Current task-local (or thread-local) scope.
    /// By default it's ``global`` and can be changed with ``callAsFunction(body:)-4envx`` method.
    ///
    /// Current scope affects ``KvEnvironment`` property wrapper.
    /// See documentation of ``KvEnvironment`` for details.
    ///
    /// - SeeAlso: ``global``, ``KvEnvironment``.
    public static var current: KvEnvironmentScope { .taskLocal ?? .global }

    @usableFromInline
    static var _current: KvEnvironmentScope { .taskLocal ?? ._global }

    @TaskLocal
    static var taskLocal: KvEnvironmentScope?

#if swift(>=6.0)
    nonisolated(unsafe) static var _global = KvEnvironmentScope(parent: nil)
#else // swift(<6.0)
    static var _global = KvEnvironmentScope(parent: nil)
#endif // swift(<6.0)

    // - NOTE: Recursive lock is used to provide consistent public interface
    //     and avoid dead locks when static `lock()` and `unlock()` are used.
    private static let mutationLock = NSRecursiveLock()

    public var parent: KvEnvironmentScope? {
        get { withLock { _parent } }
        set { withLock { _parent = newValue } }
    }

    @usableFromInline
    var _parent: KvEnvironmentScope?

    @usableFromInline
    var container: [ObjectIdentifier : Any] = .init()

    @usableFromInline
    let mutationLock = NSLock()

    // MARK: Initialization

    /// - Parameter parent: It's designated to be `global` by default and `nil` for stand-alone scopes.
    ///
    /// - Note: There is no default value for `parent` to avoid ambiguity in code like `KvEnvironmentScope { ... }`
    ///     that can be equal to `let s = KvEnvironmentScope(); s { ... }`.
    @usableFromInline
    internal init(parent: KvEnvironmentScope?) {
        self.parent = parent
    }

    /// Initializes a scope and takes a trailing block to provide custom initialization.
    ///
    /// - Parameter parent: Parent scope that new instance inherits. Default is ``global``. Pass `nil` to create a root scope.
    /// - Parameter contentBlock: Custom block that is passed with new empty scope just before initializer returns.
    ///
    /// - SeeAlso: ``empty(parent:)``.
    public convenience init(parent: KvEnvironmentScope? = .global, contentBlock: (borrowing KvEnvironmentScope) -> Void) {
        self.init(parent: parent)

        self.callAsFunction(body: contentBlock)
    }

    /// Creates an empty scope.
    ///
    /// - Parameter parent: Parent scope that new instance inherits. Default is ``global``. Pass `nil` to create a root scope.
    ///
    /// - Returns: Created empty scope.
    ///
    /// - SeeAlso: ``init(parent:contentBlock:)``.
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
    /// If there is no value in the receiver and it's ancestors then ``KvEnvironmentKey/defaultValue`` is instantiated, saved in the receiver and returned.
    ///
    /// Setter saves given value in the receiver.
    ///
    /// - Note: This subscript is thread-safe.
    ///
    /// - Note: Unlike standard `Dictionary` this subscript is unable to remove values.
    ///     Use ``removeValue(forKey:)`` instead.
    ///
    /// - SeeAlso: ``removeValue(forKey:)``.
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
    /// - SeeAlso: ``subscript(_:)``.
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

    /// Acquires exclusive access to the receiver.
    /// Access from any other thread will will be paused until ``unlock()-swift.method`` is invoked from the same thread.
    ///
    /// - Important: ``unlock()-swift.method`` must be called to release exclusive access.
    ///     Consider ``withLock(_:)-swift.method`` method whenever possible instead of ``lock()-swift.method`` and ``unlock()-swift.method``
    ///     to guarantee release of exclusive access.
    ///
    /// - SeeAlso: ``withLock(_:)-swift.method``, ``unlock()-swift.method``.
    @inlinable public func lock() { mutationLock.lock() }

    /// Releases exclusive access acquired by ``lock()-swift.method`` method.
    ///
    /// - Important: Consider ``withLock(_:)-swift.method`` method whenever possible instead of ``lock()-swift.method`` and ``unlock()-swift.method``
    ///     to guarantee release of exclusive access.
    ///
    /// - SeeAlso: ``withLock(_:)-swift.method``, ``lock()-swift.method``.
    @inlinable public func unlock() { mutationLock.unlock() }

#if swift(<6.0) && !canImport(Darwin)
    /// A convenient method that invokes ``lock()-swift.method``, then given *body* block and then invokes ``unlock()-swift.method`` anyway.
    ///
    /// - Returns: The result of *body* block.
    ///
    /// - SeeAlso: ``lock()-swift.method``, ``unlock()-swift.method``.
    @inlinable public func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock()
        defer { unlock() }

        return try body()
    }
#endif // swift(<6.0) && !canImport(Darwin)

    // MARK: Static Locking

    /// Acquires exclusive access to static mutable state of ``KvEnvironmentScope``, e.g. ``global`` property.
    /// Access from any other thread will will be paused until ``unlock()-swift.type.method`` is invoked from the same thread.
    ///
    /// - Important: ``unlock()-swift.type.method`` must be called to release exclusive access.
    ///     Consider ``withLock(_:)-swift.type.method`` method whenever possible
    ///     instead of ``lock()-swift.type.method`` and ``unlock()-swift.type.method`` to guarantee release of exclusive access.
    ///
    /// - SeeAlso: ``withLock(_:)-swift.type.method``, ``unlock()-swift.type.method``.
    public static func lock() { mutationLock.lock() }

    /// Releases exclusive access acquired by ``lock()-swift.type.method`` method.
    ///
    /// - Important: Consider ``withLock(_:)-swift.type.method`` method whenever possible
    ///     instead of ``lock()-swift.type.method`` and ``unlock()-swift.type.method`` to guarantee release of exclusive access.
    ///
    /// - SeeAlso: ``withLock(_:)-swift.type.method``, ``lock()-swift.type.method``.
    public static func unlock() { mutationLock.unlock() }

    /// A convenient method that invokes ``lock()-swift.type.method``, then given *body* block and then invokes ``unlock()-swift.type.method`` anyway.
    ///
    /// - Returns: The result of *body* block.
    ///
    /// - SeeAlso: ``lock()-swift.type.method``, ``unlock()-swift.type.method``.
    public static func withLock<R>(_ body: () throws -> R) rethrows -> R {
#if swift(>=6.0) || canImport(Darwin)
        try mutationLock.withLock(body)
#else // swift(<6.0) && !canImport(Darwin)
        lock()
        defer { unlock() }

        return try body()
#endif // swift(<6.0) && !canImport(Darwin)
    }

    // MARK: Operations

    /// Scope supports call-as-function semantics to temporary override ``current`` task-local (or thread-local) scope
    /// while given *body* block is running.
    ///
    /// ``KvEnvironment`` property wrapper resolves the references in ``current`` scope by default
    /// so call-as-function semantics helps to override scope with no need to modify existing instances of types with dependencies.
    /// For example:
    /// ```swift
    /// struct C {
    ///     @KvEnvironment(\.serviceA) private var serviceA
    /// }
    ///
    /// let c = C()
    /// 
    /// // Here `c.serviceA` is resolved in `global` scope
    /// print(c.serviceA)
    ///
    /// // Replacing `current` scope with call-as-function semantics
    /// someScope {
    ///     // Here `c.serviceA` is resolved in `someScope`
    ///     print(c.serviceA)
    /// }
    /// ```
    ///
    /// - Note: There are all sync/async throwing/non-throwing overloads of this method.
    ///
    /// - SeeAlso: ``current``, ``callAsFunction(body:)-90rzi``.
    @KvEnvironmentScopeAsyncThrowsOverloads
    public func callAsFunction(body: () -> Void) {
        KvEnvironmentScope.$taskLocal.withValue(self, operation: body)
    }

    /// Analog of ``callAsFunction(body:)-4envx`` there *body* is passed with the receiver.
    /// It's convenient to apply batch modifications to scopes using call-as-function semantics.
    /// Below is an example where ``global`` is modified:
    /// ```swift
    /// KvEnvironmentScope.global {
    ///     $0.serviceA = someValueA
    ///     $0.serviceB = someValueB
    ///     $0.serviceC = someValueC
    /// }
    /// ```
    ///
    /// - Note: There are all sync/async throwing/non-throwing overloads of this method.
    ///
    /// - SeeAlso: ``callAsFunction(body:)-4envx``.
    @KvEnvironmentScopeAsyncThrowsOverloads
    public func callAsFunction(body: (borrowing KvEnvironmentScope) -> Void) {
        KvEnvironmentScope.$taskLocal.withValue(self) {
            body(self)
        }
    }

    /// This method changes ``KvEnvironment/scope`` to the receiver
    /// for properties of *instance* having ``KvEnvironment`` attribute.
    ///
    /// If ``ReplaceOptions/recursive`` is passed then this method is recursively called for values of affected properties.
    /// Cycles in the dependency graph are properly handled.
    ///
    /// - SeeAlso: ``replace(in:options:)-7g4rs``, ``replace(in:_:_:options:)``.
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

    /// This overload of ``replace(in:options:)-4j9gb`` affects all instances in given sequence.
    ///
    /// - SeeAlso: ``replace(in:options:)-4j9gb``, ``replace(in:_:_:options:)``.
    @inlinable
    public func replace<I>(in instances: I, options: ReplaceOptions = []) where I: Sequence {
        var visitedIDs = Set<ObjectIdentifier>()

        instances.forEach {
            _replace(in: $0, options: options, visitedIDs: &visitedIDs)
        }
    }

    /// This overload of ``replace(in:options:)-4j9gb`` affects all given instances.
    ///
    /// - SeeAlso: ``replace(in:options:)-4j9gb``, ``replace(in:options:)-7g4rs``.
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

/// This macro is a simple way to declare environment properties.
/// With this macro environment properties are declared just like usual properties with type annotations and initial values.
/// Also environment keys are created automatically.
///
/// ```swift
/// extension KvEnvironmentScope {
///     #kvEnvironment {
///         var a: A?
///         var b1: B = .first, b2: B = .second
///         let b3: B = .third
///     }
///     fileprivate #kvEnvironment { var c: C }
/// }
/// ```
///
/// This macro is compatible with attributes and modifiers.
/// Constant declarations are transformed to computed properties having getters only.
///
/// Implicit initial value of optional types is `nil`.
/// Opaque types without initial value are permitted but they must be initialized before first use.
///
/// - SeeAlso: ``KvEnvironmentScope``.
@freestanding(declaration, names: arbitrary)
public macro kvEnvironment(properties: () -> Void) = #externalMacro(module: "kvEnvironmentMacros", type: "KvEnvironmentScopeEntryMacro")

// MARK: - macro KvEnvironmentScopeOverloads

/// This macro creates overloads of a function having `async`, `throws` and `async throws` effects on the method and any closure parameter.
@attached(peer, names: overloaded)
private macro KvEnvironmentScopeAsyncThrowsOverloads() = #externalMacro(
    module: "kvEnvironmentMacros",
    type: "KvEnvironmentScopeAsyncThrowsOverloadsMacro"
)
