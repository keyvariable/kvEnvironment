//===----------------------------------------------------------------------===//
//
//  Copyright (c) 2025 Svyatoslav Popov (info@keyvar.com).
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
//  KvEnvironmentScopeOverloadsMacro.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 03.01.2025.
//

import Foundation

import SwiftSyntax
import SwiftSyntaxMacros

package struct KvEnvironmentScopeOverloadsMacro: PeerMacro {
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
        else { throw ExpansionError("a nonthrowing function is required") }

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

        var description: String { "@KvEnvironmentScopeOverloads: \(message)" }
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
