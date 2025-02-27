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
//  KvEnvironmentScopeEntryMacro.swift
//  KvEnvironment
//
//  Created by Svyatoslav Popov on 06.01.2025.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct KvEnvironmentScopeEntryMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let closure: ClosureExprSyntax

        switch node.argumentList.last {
        case .none:
            guard let trailingClosure = node.trailingClosure
            else { throw ExpansionError.singleClosureArgumentRequirement }

            closure = trailingClosure

        case .some(let argument):
            guard node.argumentList.count == 1,
                  let closureArgument = argument.expression.as(ClosureExprSyntax.self)
            else { throw ExpansionError.singleClosureArgumentRequirement }

            closure = closureArgument
        }

        return try Array(closure.statements
            .lazy.map { statement in
                guard let variableDecl = statement.item.as(VariableDeclSyntax.self)
                else { throw ExpansionError.unexpectedStatement(statement, "only variable declarations are expected") }

                return try expansion(of: variableDecl)
            }
            .joined())
    }

    private static func expansion(
        of variableDecl: VariableDeclSyntax
    ) throws -> some Sequence<DeclSyntax> {
        guard variableDecl.attributes.isEmpty,
              variableDecl.modifiers.isEmpty
        else { throw ExpansionError.unexpectedStatement(variableDecl, "attributes and modifiers are not supported") }

        let expansionBlock = try self.expansionBlock(for: variableDecl)

        return try variableDecl.bindings
            .lazy.map(expansionBlock)
            .joined()
    }

    private static func expansionBlock(
        for variableDecl: VariableDeclSyntax
    ) throws -> ((PatternBindingSyntax) throws -> [DeclSyntax]) {
        switch variableDecl.bindingSpecifier.tokenKind {
        case .keyword(.let):
            return { binding in
                let entry = try EntryDescription.from(binding)

                guard let initialValue = entry.initialValue
                else { throw ExpansionError.unexpectedStatement(variableDecl, "`let` declarations must have initial value") }

                return [
                    "var \(entry.identifier): \(entry.type) { return \(initialValue) }",
                ]
            }

        case .keyword(.var):
            return { binding in
                let entry = try EntryDescription.from(binding)

                let keyTypeID: DeclSyntax = "Key_\(entry.identifier.trimmed)"
                let keyBody: DeclSyntax = entry.initialValue.map {
                    "static var defaultValue: \(entry.type) { return \($0) }"
                } ?? "typealias Value = \(entry.type)"

                return [
                    "struct \(keyTypeID) : KvEnvironmentKey { \(keyBody) }",
                    """
                    var \(entry.identifier): \(entry.type) {
                        get { self[\(keyTypeID).self] }
                        set { self[\(keyTypeID).self] = newValue }
                    }
                    """,
                ]
            }

        default:
            throw ExpansionError.unexpectedStatement(variableDecl, "only `let` and `var` binding specifiers are supported")
        }
    }

    // MARK: .EntryDescription

    private struct EntryDescription {
        let identifier: TokenSyntax
        let type: TypeSyntax
        let initialValue: ExprSyntax?

        // MARK: Initialization

        static func from(_ binding: PatternBindingSyntax) throws -> EntryDescription {
            guard binding.accessorBlock == nil
            else { throw ExpansionError.unexpectedStatement(binding, "only stored variables are expected") }

            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier
            else { throw ExpansionError.unexpectedStatement(binding, "a variable identifier is expected") }

            guard let type = binding.typeAnnotation?.type
            else { throw ExpansionError.unexpectedStatement(binding, "type annotations are required") }

            let initialValue = binding.initializer?.value ?? {
                // Initial value for optional types is `nil`.
                guard type.as(OptionalTypeSyntax.self) != nil
                        || type.as(IdentifierTypeSyntax.self)?.name.tokenKind == .identifier("Optional")
                else { return nil }

                return "nil"
            }()

            return .init(identifier: identifier, type: type, initialValue: initialValue)
        }
    }

    // MARK: .ExpansionError

    private struct ExpansionError: Error, CustomStringConvertible {
        private let message: String

        // MARK: Initialization

        init(_ message: String) { self.message = message }

        static var singleClosureArgumentRequirement: ExpansionError {
            .init("single closure argument is required")
        }

        static func unexpectedStatement(_ statement: SyntaxProtocol, _ message: String) -> ExpansionError {
            .init("unexpected statement «\(statement.trimmed)», \(message)")
        }

        // MARK: + CustomStringConvertible

        var description: String { "#kvEnvironmentScope: \(message)" }
    }
}
