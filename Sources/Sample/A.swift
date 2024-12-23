import kvEnvironment

struct A {
    let a: Int
}

/// Example of a key having an optional value.
extension KvEnvironmentValues {
    private struct AKey : KvEnvironmentKey {
        static var defaultValue: A? { nil }
    }

    var a: A? {
        get { self[AKey.self] }
        set { self[AKey.self] = newValue }
    }
}
