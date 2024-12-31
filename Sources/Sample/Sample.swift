import kvEnvironment

@main
struct Sample {
    static func main() {
        // Graph: A — C — D
        //        B /
        do {
            /// Insertion of `C` having no default value into global scope.
            KvEnvironmentScope.global.values.c = C(c: 3.0)

            /// A child scope where only `a` is replaced.
            let childScopeA = KvEnvironmentScope(parent: .global) {
                $0.a = A(a: 1)
            }
            /// A child scope where only `b` is replaced.
            let childScopeB = KvEnvironmentScope(parent: .global) {
                $0.b = B(b: "2-nd")
            }

            /// Instance of `D` where dependencies are taken from global scope.
            print(D().description)

            /// Instance of `D` where dependencies are taken from `childScopeB`.
            let d = D(scope: childScopeB)
            print(d.description)

            /// Changing all environment references to `childScopeA`.
            childScopeA.install(to: d, options: .recursive)
            print(d.description)

            /// Replacing particular property.
            d.replace(bScope: .init {
                $0.a = A(a: 255)
                $0.b = B(b: "custom")
            })
            /// Now `a` and `c` are taken from `childScopeA`, but `b` is taken from custom scope.
            print(d.description)
        }
        // Cycles: E \
        //         |  G
        //         F /
        do {
            /// Insertion of `E` and `F` into global scope.
            KvEnvironmentScope.global.values.e = E(id: "e1")
            KvEnvironmentScope.global.values.f = F(id: "f1")

            let g = G()

            print(g)

            KvEnvironmentScope {
                $0.e = E(id: "e2")
                $0.f = F(id: "f2")
            }
            .install(to: g, options: .recursive)

            print(g)
        }
    }
}
