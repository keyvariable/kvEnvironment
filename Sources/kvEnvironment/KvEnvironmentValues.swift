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
//  KvEnvironmentValues.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 21.11.2023.
//

// TODO: DOC
public struct KvEnvironmentValues {
    var parent: KvEnvironmentScope?

    private var container: [ObjectIdentifier : Any] = [:]

    // MARK: Initialization

    public init() { }

    public init(_ transform: (inout Self) -> Void) {
        transform(&self)
    }

    // MARK: Access

    /// Getter returns the closest value in the hierarchy by given *key*.
    /// ``KvEnvironmentKey/defaultValue`` is returned if there is no value for *key*.
    public subscript<Key : KvEnvironmentKey>(key: Key.Type) -> Key.Value {
        get { value(forKey: key) ?? key.defaultValue }
        set { container[ObjectIdentifier(key)] = newValue }
    }

    func value<Key : KvEnvironmentKey>(forKey key: Key.Type) -> Key.Value? {
        firstResult { $0.container[ObjectIdentifier(key)] }
            .map { $0 as! Key.Value }
    }

    private func firstResult<T>(of block: (borrowing KvEnvironmentValues) -> T?) -> T? {
        if let value = block(self) {
            return value
        }

        do {
            var container = self

            while let next = container.parent?.values {
                if let value = block(next) {
                    return value
                }

                container = next
            }
        }

        return nil
    }
}
