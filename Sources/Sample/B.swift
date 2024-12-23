import kvEnvironment

class B {
    let b: String

    init(b: String) {
        self.b = b
    }

    static let `default` = B(b: "default")
}

/// Example of a key having a default value.
extension KvEnvironmentValues {
    private struct BKey : KvEnvironmentKey {
        static var defaultValue: B { .default }
    }

    var b: B {
        get { self[BKey.self] }
        set { self[BKey.self] = newValue }
    }
}
