//===----------------------------------------------------------------------===//
//
//  Copyright (c) 2023 Svyatoslav Popov (info@keyvar.com).
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

public class KvEnvironmentScope {
    public static var global = KvEnvironmentScope()

    public var values: KvEnvironmentValues

    // MARK: Initialization

    public init(_ values: KvEnvironmentValues = .init()) {
        self.values = values

        guard !values.isEmpty else { return }

        var visitedIDs = Set<ObjectIdentifier>()

        values.forEach {
            installRecursive(to: $0, visitedIDs: &visitedIDs)
        }
    }

    public convenience init(_ transform: (inout KvEnvironmentValues) -> Void) {
        self.init(KvEnvironmentValues(transform))
    }

    public convenience init(_ values: KvEnvironmentValues = .init(), parent: KvEnvironmentScope?) {
        var values = values
        values.parent = parent
        self.init(values)
    }

    public convenience init(parent: KvEnvironmentScope?, _ transform: (inout KvEnvironmentValues) -> Void) {
        self.init(KvEnvironmentValues(transform), parent: parent)
    }

    // MARK: Operations

    // TODO: DOC
    public func install(to instance: Any, options: InstallOptions = []) {
        switch options.contains(.recursive) {
        case false:
            Mirror(reflecting: instance).children.forEach {
                guard let reference = $0.value as? KvEnvironmentProtocol else { return }

                reference.scope = self
            }

        case true:
            var visitedIDs = Set<ObjectIdentifier>()

            installRecursive(to: instance, visitedIDs: &visitedIDs)
        }
    }

    private func installRecursive(to instance: Any, visitedIDs: inout Set<ObjectIdentifier>) {
        // Recursively enumerating properties wrapped with `@KvEnvironment`.
        //
        // - NOTE: For-in cycle is used to reduce depth of recursion.
        for property in Mirror(reflecting: instance).children {
            guard let reference = property.value as? KvEnvironmentProtocol,
                  visitedIDs.insert(ObjectIdentifier(reference)).inserted
            else { continue }

            reference.scope = self

            installRecursive(to: reference.erasedWrappedValue, visitedIDs: &visitedIDs)
        }
    }

    // MARK: .InstallOptions

    public struct InstallOptions: OptionSet, ExpressibleByIntegerLiteral {
        public static var recursive: InstallOptions = 0x01

        // MARK: + OptionSet

        public typealias RawValue = UInt8

        public let rawValue: RawValue

        @inlinable public init(rawValue: RawValue) { self.rawValue = rawValue }

        // MARK: + ExpressibleByIntegerLiteral

        @inlinable public init(integerLiteral value: IntegerLiteralType) { self.init(rawValue: numericCast(value)) }
    }
}
