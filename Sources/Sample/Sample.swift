import kvEnvironment

@main
struct Sample {
    static func main() {
        // Graph: A — C — D
        //        B /

        /// Insertion of C having to default value into global scope.
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
        childScopeA.install(to: d)
        print(d.description)

        /// Replacing particular property.
        d.replace(bScope: .init {
            $0.a = A(a: 255)
            $0.b = B(b: "custom")
        })
        /// Now `a` and `c` are taken from `childScopeA`, but `b` is taken from custom scope.
        print(d.description)
    }
}
