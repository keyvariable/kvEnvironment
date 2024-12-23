import kvEnvironment

class D: CustomStringConvertible {
    @KvEnvironment(\.c) private var c

    init() { }

    init(scope: KvEnvironmentScope) {
        scope.install(to: self)
    }

    var description: String { "D(c: \(c))" }

    /// Replace scope of `c.b` property only.
    func replace(bScope: KvEnvironmentScope) {
        c.replace(bScope: bScope)
    }
}
