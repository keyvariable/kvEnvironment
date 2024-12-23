import Foundation

import kvEnvironment

class C: CustomStringConvertible {
    @KvEnvironment(\.a) private var a
    @KvEnvironment(\.b) private var b

    private let c: Double

    init(c: Double) {
        self.c = c
    }

    var description: String {
        "C(a: \(a.map { "\($0.a)" } ?? "–"), b: \"\(b.b)\"\(String(repeating: " ", count: max(0, 7 - b.b.count))), c: \(c))"
    }

    /// Replace scope of `b` property only.
    func replace(bScope: KvEnvironmentScope) {
        _b.scope = bScope
    }
}

/// Example of a key having no default value.
extension KvEnvironmentValues {
    private struct CKey : KvEnvironmentKey { typealias Value = C }

    var c: C {
        get { self[CKey.self] }
        set { self[CKey.self] = newValue }
    }
}
