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
    }

    public convenience init(_ transform: (inout KvEnvironmentValues) -> Void) {
        self.init(KvEnvironmentValues(transform))
    }

    public init(_ values: KvEnvironmentValues = .init(), parent: KvEnvironmentScope?) {
        var values = values
        values.parent = parent
        self.values = values
    }

    public convenience init(parent: KvEnvironmentScope?, _ transform: (inout KvEnvironmentValues) -> Void) {
        self.init(KvEnvironmentValues(transform), parent: parent)
    }

    // MARK: Operations

    // TODO: DOC
    public func install(to instance: Any) {
        KvEnvironmentScope.forEachEnvironmentProperty(of: instance) {
            $0.scope = self
        }
    }

    private static func forEachEnvironmentProperty(of instance: Any, body: (KvEnvironmentProtocol) -> Void) {

        func Process(_ instance: Any) {
            // Recursively enumerating properties wrapped with `@KvEnvironment` or those values may contain wrapped properties.
            Mirror(reflecting: instance).children.forEach {
                let next: Any

                switch $0.value {
                case let value as KvEnvironmentProtocol:
                    body(value)

                    guard let instance = value.scope?.values[keyPath: value.keyPath] else { return }

                    next = instance

                default:
                    next = $0.value
                }

                Process(next)
            }
        }

        Process(instance)
    }
}
