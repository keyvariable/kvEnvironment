import kvEnvironment

@main
struct Sample {
    static func main() {
        // Graph: A — C — D
        //        B /
        do {
            /// Insertion of `C` having no default value into global scope.
            KvEnvironmentScope.global {
                $0.c = C(c: 3.0)
            }

            /// A child scope where only `a` is replaced.
            let childScopeA = KvEnvironmentScope {
                $0.a = A(a: 1)
            }
            /// A child scope where only `b` is replaced.
            let childScopeB = KvEnvironmentScope {
                $0.b = B(b: "2-nd")
            }

            do {
                /// Instance of `D` where dependencies are taken from default scope.
                let d = D()

                /// Currently default scope is `.global`.
                print(d)

                /// Changing the current scope to `childScopeB`.
                childScopeB { _ in
                    print(d)
                }
            }
            do {
                /// Instance of `D` where dependencies are taken from `childScopeB`.
                let d = D(scope: childScopeB)
                print(d.description)

                /// Changing all environment references to `childScopeA`.
                childScopeA.replace(in: d, options: .recursive)
                print(d.description)

                /// Replacing scope for particular property.
                d.replace(bScope: .init {
                    $0.a = A(a: 255)
                    $0.b = B(b: "custom")
                })
                /// Now `a` and `c` are taken from `childScopeA`, but `b` is taken from custom scope.
                print(d.description)
            }
        }
        // Cycles: E \
        //         |  G
        //         F /
        do {
            /// Insertion of `E` and `F` into global scope.
            KvEnvironmentScope.global {
                $0.e = E(id: "e1")
                $0.f = F(id: "f1")
            }

            let g = G()

            print(g)

            KvEnvironmentScope {
                $0.e = E(id: "e2")
                $0.f = F(id: "f2")
            }
            .replace(in: g, options: .recursive)

            print(g)
        }
    }
}
