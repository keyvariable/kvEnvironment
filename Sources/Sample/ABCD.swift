import kvEnvironment

struct A {
    let a: Int
}
extension A: ExpressibleByIntegerLiteral {
    init(integerLiteral value: IntegerLiteralType) { self.init(a: value) }
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
        /// A property with xplicit default value.
        var b: B = .default
        /// A property having no default value.
        var c: C
    }
    /// Constant declarations are transformed to computed properties having getters only.
    #kvEnvironment { let a_ee: A = 0xEE, a_ff: A? = 0xFF }
}
