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
//  KvEnvironment.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 21.11.2023.
//

// MARK: - KvEnvironmentProtocol

/// This protocol is used to enumerate properties with ``KvEnvironment`` wrapper.
protocol KvEnvironmentProtocol : AnyObject {
    var keyPath: PartialKeyPath<KvEnvironmentValues> { get }

    var scope: KvEnvironmentScope? { get set }
}

// MARK: - KvEnvironment

@propertyWrapper
public class KvEnvironment<Value> : KvEnvironmentProtocol {
    public var scope: KvEnvironmentScope?

    private let _keyPath: KeyPath<KvEnvironmentValues, Value>

    // MARK: Initialization

    public init(_ keyPath: KeyPath<KvEnvironmentValues, Value>, in scope : KvEnvironmentScope? = nil) {
        _keyPath = keyPath
        self.scope = scope
    }

    // MARK: + KvEnvironmentProtocol

    var keyPath: PartialKeyPath<KvEnvironmentValues> { _keyPath }

    // MARK: Operations

    public var wrappedValue: Value {
        guard let scope = scope ?? .global
        else { fatalError("No installed or global scope") }

        return scope.values[keyPath: _keyPath]
    }
}
