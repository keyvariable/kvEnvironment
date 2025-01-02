import kvEnvironment

struct A {
    let a: Int
}

class B {
    let b: String

    init(b: String) {
        self.b = b
    }

    static let `default` = B(b: "default")
}

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

class D: CustomStringConvertible {
    @KvEnvironment(\.c) private var c

    init() { }

    init(scope: KvEnvironmentScope) {
        scope.replace(in: self, options: .recursive)
    }

    var description: String { "D(c: \(c))" }

    /// Replace scope of `c.b` property only.
    func replace(bScope: KvEnvironmentScope) {
        c.replace(bScope: bScope)
    }
}

extension KvEnvironmentScope {
    /// Example of a key having an optional value.
    private struct AKey : KvEnvironmentKey {
        static var defaultValue: A? { nil }
    }

    /// Example of a key having a default value.
    private struct BKey : KvEnvironmentKey {
        static var defaultValue: B { .default }
    }

    /// Example of a key having no default value.
    private struct CKey : KvEnvironmentKey { typealias Value = C }

    var a: A? {
        get { self[AKey.self] }
        set { self[AKey.self] = newValue }
    }

    var b: B {
        get { self[BKey.self] }
        set { self[BKey.self] = newValue }
    }

    var c: C {
        get { self[CKey.self] }
        set { self[CKey.self] = newValue }
    }
}
