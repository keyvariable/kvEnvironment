import kvEnvironment

@main
struct Sample {
    static func main() {
        KvEnvironmentScope.global = .init(.init())

        let childScope1 = KvEnvironmentScope(
            .init {
                $0.a = .init(a: 1)
            },
            parent: .global
        )
        let childScope2 = KvEnvironmentScope(
            .init {
                $0.b = .init(b: "2-nd")
            },
            parent: .global
        )

        // Default scope
        print(C().description)

        // Custom child scope
        let c = C(scope: childScope1)
        print(c.description)

        // Replacing scope
        childScope2.install(to: c)
        print(c.description)

        // Replacing particular property
        c.replace(bScope: .init {
            $0.a = .init(a: 255)
            $0.b = .init(b: "custom")
        })
        print(c.description)
    }
}
