import kvEnvironment

@main
struct Sample {
    static func main() {
        KvEnvironmentScope.global.values.c = C()

        let childScopeA = KvEnvironmentScope(parent: .global) {
            $0.a = A(a: 1)
        }
        let childScopeB = KvEnvironmentScope(parent: .global) {
            $0.b = B(b: "2-nd")
        }

        // Default scope
        print(D().description)

        // Custom child scope
        let d = D(scope: childScopeA)
        print(d.description)

        // Replacing scope
        childScopeB.install(to: d)
        print(d.description)

        // Replacing particular property
        d.replace(bScope: .init {
            $0.a = A(a: 255)
            $0.b = B(b: "custom")
        })
        print(d.description)
    }
}
