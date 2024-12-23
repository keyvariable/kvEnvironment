import kvEnvironment

class C: CustomStringConvertible {
    @KvEnvironment(\.a) private var a
    @KvEnvironment(\.b) private var b

    init() {}

    init(scope: KvEnvironmentScope) {
        scope.install(to: self)
    }

    var description: String { "a.a = \(a.map { "\($0.a)" } ?? "nil"), b.b = \"\(b.b)\"" }

    func replace(bScope: KvEnvironmentScope) {
        _b.scope = bScope
    }
}
