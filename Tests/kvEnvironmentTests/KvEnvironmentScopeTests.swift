//===----------------------------------------------------------------------===//
//
//  Copyright (c) 2025 Svyatoslav Popov (info@keyvar.com).
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
//  KvEnvironmentScopeTests.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 16.02.2025.
//

import XCTest

@testable import kvEnvironment

class KvEnvironmentScopeTests : XCTestCase {
    func testBasics() {
        XCTAssertNil(KvEnvironmentScope.global.a)
        XCTAssertEqual(KvEnvironmentScope.global.b.value, "default")

        // Initialization of global.c
        do {
            let globalC = C(value: 3.0)
            assertEqual(globalC.a, KvEnvironmentScope.global.a)
            assertEqual(globalC.b, KvEnvironmentScope.global.b)

            /// Insertion of `C` having no default value into global scope.
            KvEnvironmentScope.global {
                $0.c = globalC
            }
            assertEqual(KvEnvironmentScope.global.c, globalC)
        }

        // Initialization of childScopeA
        let childScopeA: KvEnvironmentScope
        do {
            let a1 = A(value: 1)

            childScopeA = KvEnvironmentScope {
                $0.a = a1
            }
            assertEqual(childScopeA.a, a1)
            assertEqual(childScopeA.b, KvEnvironmentScope.global.b)
            assertEqual(childScopeA.c, KvEnvironmentScope.global.c)
        }

        // Initialization of childScopeB
        let childScopeB: KvEnvironmentScope
        do {
            let b2 = B(value: "2-nd")

            childScopeB = KvEnvironmentScope {
                $0.b = b2
            }
            assertEqual(childScopeB.a, KvEnvironmentScope.global.a)
            assertEqual(childScopeB.b, b2)
            assertEqual(childScopeB.c, KvEnvironmentScope.global.c)
        }

        // Changing current scope
        do {
            let d = D()
            /// Here `d` resolves environment references in global (current) scope.
            assert(d, c: KvEnvironmentScope.global.c)
            /// Changing the current scope to `childScopeB`.
            childScopeB {
                /// Here `d` resolves environment references in `childScopeB` (current).
                assert(d, c: childScopeB.c)
            }
        }

        // Replacing scopes
        do {
            let d = D(scope: childScopeB)
            /// Here `d` resolves environment references in `childScopeB`.
            assert(d, c: childScopeB.c)
            /// Changing all environment references in `d` to `childScopeA`.
            childScopeA.replace(in: d, options: .recursive)
            assert(d, c: childScopeA.c)

            /// Replacing scope for particular property.
            let customScope = KvEnvironmentScope {
                $0.a = A(value: 255)
                $0.b = B(value: "custom")
            }
            d.replace(bScope: customScope)

            /// Now `a` and `c` are taken from `childScopeA`, but `b` is taken from `customScope`.
            assertEqual(d.c.a, childScopeA.a)
            assertEqual(d.c.b, customScope.b)
            XCTAssertEqual(d.c.value, childScopeA.c.value)
        }
    }

    func testCyclicDependencies() {
        /// Insertion of `E` and `F` into global scope.
        KvEnvironmentScope.global {
            $0.e = E(id: "e1")
            $0.f = F(id: "f1")
        }

        let g = G()

        assert(g, in: .global)

        let scope = KvEnvironmentScope {
            $0.e = E(id: "e2")
            $0.f = F(id: "f2")
        }
        scope.replace(in: g, options: .recursive)

        assert(g, in: scope)
    }

    func testFileprivateComputedProperties() {

        func assert(scope: KvEnvironmentScope) {
            XCTAssertEqual(scope.a_ee.value, 0xEE)
            XCTAssertEqual(scope.a_ff?.value, 0xFF)
        }

        assert(scope: .global)
        assert(scope: .init { _ in })
        assert(scope: .init(parent: nil) { _ in })
    }

    // MARK: Auxiliaries

    private func assertEqual(_ lhs: A?, _ rhs: A?) {
        XCTAssertEqual(lhs?.value, rhs?.value)
    }

    private func assertEqual(_ lhs: B, _ rhs: B) {
        XCTAssertEqual(lhs.value, rhs.value)
    }

    private func assertEqual(_ lhs: C, _ rhs: C) {
        XCTAssertEqual(lhs.value, rhs.value)
        assertEqual(lhs.a, rhs.a)
        assertEqual(lhs.b, rhs.b)
    }

    private func assert(_ d: D, c: C) {
        assertEqual(d.c, c)
    }

    private func assert(_ g: G, in scope: KvEnvironmentScope) {
        XCTAssertEqual(g.e.id, scope.e.id)
        XCTAssertEqual(g.e.id, g.e.f.e.id)

        XCTAssertEqual(g.f.id, scope.f.id)
        XCTAssertEqual(g.f.id, g.f.e.f.id)
    }
}

// MARK: - File-private Environment Properties

extension KvEnvironmentScope {
    /// Constant declarations are transformed to computed properties having getters only.
    ///
    /// `#kvEnvironment` is compatible with attributes and modifiers.
    fileprivate #kvEnvironment { let a_ee: A = .init(value: 0xEE), a_ff: A? = .init(value: 0xFF) }
}
