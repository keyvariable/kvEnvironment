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
    private struct EKey : KvEnvironmentKey { typealias Value = E }
    private struct FKey : KvEnvironmentKey { typealias Value = F }

    var e: E {
        get { self[EKey.self] }
        set { self[EKey.self] = newValue }
    }
    var f: F {
        get { self[FKey.self] }
        set { self[FKey.self] = newValue }
    }
}
