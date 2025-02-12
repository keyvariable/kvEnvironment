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
//  KvEnvironmentScopeAsyncThrowsOverloadsMacro.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 03.01.2025.
//

import Foundation

import SwiftSyntax
import SwiftSyntaxMacros

package struct KvEnvironmentScopeAsyncThrowsOverloadsMacro: PeerMacro {
    package static func expansion<Context: MacroExpansionContext, Declaration: DeclSyntaxProtocol>(
        of node: AttributeSyntax,
        providingPeersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax] {
        let templateDecl = try self.templateDecl(from: node, declaration)

        return [
            try overloadDecl(templateDecl, effects: .async),
            try overloadDecl(templateDecl, effects: .throws),
            try overloadDecl(templateDecl, effects: [ .async, .throws ]),
        ]
    }

    private static func templateDecl<Declaration: DeclSyntaxProtocol>(
        from node: AttributeSyntax,
        _ declaration: Declaration
    ) throws -> FunctionDeclSyntax {
        guard var originDecl = declaration.as(FunctionDeclSyntax.self)
        else { throw ExpansionError("it can only be applied to functions") }

        guard originDecl.signature.effectSpecifiers?.asyncSpecifier == nil
        else { throw ExpansionError("a non-async function is required") }

        guard originDecl.signature.effectSpecifiers?.throwsSpecifier == nil
        else { throw ExpansionError("a non-throwing function is required") }

        // Dropping the macro attribute.
        originDecl.attributes = originDecl.attributes.filter {
            guard case let .attribute(attribute) = $0,
                  let attributeIdentifier = attribute.attributeName.as(IdentifierTypeSyntax.self),
                  let nodeAttributeIdentifier = node.attributeName.as(IdentifierTypeSyntax.self)
            else { return true }

            return attributeIdentifier.name.text != nodeAttributeIdentifier.name.text
        }

        return originDecl
    }

    private static func overloadDecl(_ templateDecl: FunctionDeclSyntax, effects: EffectOptions) throws -> DeclSyntax {
        var overloadDecl = templateDecl

        let signatureEffectSpecifiers = FunctionEffectSpecifiersSyntax(
            asyncSpecifier: effects.contains(.async) ? .keyword(.async) : nil,
            throwsSpecifier: effects.contains(.throws) ? .keyword(.rethrows) : nil
        )

        overloadDecl.signature.parameterClause.parameters = .init(overloadDecl.signature.parameterClause.parameters.map {
            guard var typeSyntax = $0.type.as(FunctionTypeSyntax.self)
            else { return $0 }

            typeSyntax.effectSpecifiers = .init(
                asyncSpecifier: effects.contains(.async) ? .keyword(.async) : nil,
                throwsSpecifier: effects.contains(.throws) ? .keyword(.throws) : nil
            )

            return map($0) {
                $0.type = .init(typeSyntax)
            }
        })

        overloadDecl.signature.effectSpecifiers = signatureEffectSpecifiers

        try with(&overloadDecl.body) {
            try process(statements: &$0.statements, effects: effects)
        }

        return .init(overloadDecl)
    }

    private static func process(statements: inout CodeBlockItemListSyntax, effects: EffectOptions) throws {
        statements = CodeBlockItemListSyntax(try statements.map {
            guard var codeBlock = $0.as(CodeBlockItemSyntax.self),
                  var functionCall = codeBlock.item.as(FunctionCallExprSyntax.self)
            else { return $0 }

            try with(&functionCall.trailingClosure) {
                try process(statements: &$0.statements, effects: effects)
            }

            var expression: ExprSyntaxProtocol = functionCall

            if effects.contains(.async) {
                expression = AwaitExprSyntax(
                    awaitKeyword: .keyword(.await),
                    expression: expression
                )
            }
            if effects.contains(.throws) {
                expression = TryExprSyntax(
                    tryKeyword: .keyword(.try),
                    expression: expression
                )
            }

            codeBlock.item = .init(expression)

            return codeBlock
        })
    }

   private static func map<T>(_ value: T, _ transform: (inout T) throws -> Void) rethrows -> T {
        var copy = value

        try transform(&copy)

        return copy
    }

    private static func with<T>(_ value: inout T?, _ transform: (inout T) throws -> Void) rethrows {
        guard var copy = value else { return }

        try transform(&copy)

        value = copy
    }

    // MARK: .ExpansionError

    private struct ExpansionError: Error, CustomStringConvertible {
        private let message: String

        init(_ message: String) { self.message = message }

        var description: String { "@KvEnvironmentScopeAsyncThrowsOverloads: \(message)" }
    }

    // MARK: .EffectOptions

    private struct EffectOptions: OptionSet, ExpressibleByIntegerLiteral {
        static var async: EffectOptions { 0x01 }
        static var `throws`: EffectOptions { 0x02 }

        // MARK: + OptionSet

        typealias RawValue = UInt8

        let rawValue: RawValue

        init(rawValue: RawValue) { self.rawValue = rawValue }

        // MARK: + ExpressibleByIntegerLiteral

        init(integerLiteral value: IntegerLiteralType) { self.init(rawValue: numericCast(value)) }
    }
}
