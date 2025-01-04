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
    var erasedWrappedValue: Any { get }

    var scope: KvEnvironmentScope? { get set }
}

// MARK: - KvEnvironment

@propertyWrapper
public final class KvEnvironment<Value> : KvEnvironmentProtocol {
    public var scope: KvEnvironmentScope?

    private let keyPath: KeyPath<KvEnvironmentScope, Value>

    // MARK: Initialization

    public init(_ keyPath: KeyPath<KvEnvironmentScope, Value>, in scope: KvEnvironmentScope? = nil) {
        self.keyPath = keyPath
        self.scope = scope
    }

    // MARK: + KvEnvironmentProtocol

    var erasedWrappedValue: Any { wrappedValue }

    // MARK: + @propertyWrapper

    public var wrappedValue: Value { (scope ?? .current)[keyPath: keyPath] }

    public var projectedValue: KvEnvironment { self }
}
