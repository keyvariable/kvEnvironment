import kvEnvironment

struct E {
    let id: String

    @KvEnvironment(\.f) var f
}

struct F {
    let id: String

    @KvEnvironment(\.e) var e
}

struct G: CustomStringConvertible {
    @KvEnvironment(\.e) private var e
    @KvEnvironment(\.f) private var f

    var description: String { "G(e: \(e.id), f: \(f.id), e.f: \(e.f.id))" }
}

/// Example of a key having a default value.
extension KvEnvironmentScope {
    #kvEnvironment {
        var e: E
        var f: F
    }
}
