import kvEnvironment

struct A {
    let a: Int
}

class B {
    let b: String

    init(b: String) {
        self.b = b
    }
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
        $b.scope = bScope
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
    /// Implicit initial value of optional types is `nil`.
    #kvEnvironment { var a: A? }
    #kvEnvironment {
        /// A property with explicit default value.
        var b: B = .init(b: "default")
        /// A property having no default value.
        var c: C
    }
    /// Constant declarations are transformed to computed properties having getters only.
    ///
    /// `#kvEnvironment` is compatible with attributes and modifiers.
    fileprivate #kvEnvironment { var a_ee: A = .init(a: 0xEE), a_ff: A? = .init(a: 0xFF) }
}
/// Below is an example of explicit declaration of an environment property.
private extension KvEnvironmentScope {
    private struct aZeroKey : KvEnvironmentKey {
        static var defaultValue: A { .init(a: 0) }
    }
    var zeroA: A {
        get { self[aZeroKey.self] }
        set { self[aZeroKey.self] = newValue }
    }
}
