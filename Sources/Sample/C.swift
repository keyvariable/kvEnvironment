import Foundation

import kvEnvironment

class C: CustomStringConvertible {
    @KvEnvironment(\.a) private var a
    @KvEnvironment(\.b) private var b

    init() { }

    var description: String { "C(a: \(a.map { "\($0.a)" } ?? "–"), b: \"\(b.b)\")" }

    /// Replace scope of `b` property only.
    func replace(bScope: KvEnvironmentScope) {
        _b.scope = bScope
    }
}

extension KvEnvironmentValues {
    private struct CKey : KvEnvironmentKey { typealias Value = C }

    var c: C {
        get { self[CKey.self] }
        set { self[CKey.self] = newValue }
    }
}
