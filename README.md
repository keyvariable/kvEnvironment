# kvEnvironment

An implementation of dependency injection pattern. *kvEnvironment* provides:
- simple API;
- hierarchy of scopes with cascade resolution of properties;
- thread-safety;
- flexible ways to override scopes;
- retain-cycles-free architecture;
- lazy initialization of properties.


## Supported Platforms

There are no explicit restrictions for any platform.
So it's assumed that *kvEnvironment* can be compiled on any platform Swift is available on.


## Getting Started

#### Package Dependencies:
```swift
.package(url: "https://github.com/keyvariable/kvEnvironment.git", from: "0.2.0")
```
#### Target Dependencies:
```swift
.product(name: "kvEnvironment", package: "kvEnvironment")
```
#### Import:
```swift
import kvEnvironment
```

#### Declaration of a Scope Property:
```swift
extension KvEnvironmentScope {
    #kvEnvironment { var someProperty: SomeType }
}
```

#### Injection of a Dependency:
```swift
@KvEnvironment(\.someProperty) private var someProperty
```


## Examples

### Simple Example

Below is an example where `C` depends on `A` and `B`:
```swift
struct A { let a: Int }

struct B { let b: String }

extension KvEnvironmentScope {
    #kvEnvironment {
        var a: A?
        var b: B = .init(b: "default")
    }
}

struct C {
    @KvEnvironment(\.a) private var a
    @KvEnvironment(\.b) private var b
}
```

Environment property `a` is declared as optional.
`#kvEnvironment` macro provides implicit default value `nil` for optional types.
Environment property `b` is declared as an opaque type and has a default value.
So `C` can be instantiated in any scope at any moment due to the defaults are provided.

If an environment property is defined with no default value,
then it have to be initialized explicitly before it\'s getter is invoked.

### Scopes

There are global (`KvEnvironmentScope.global`) and task-local (`KvEnvironmentScope.current`) scopes.
It's possible to create standalone or overriding scopes:
```swift
// By default new scopes override global scope.
let aScope = KvEnvironmentScope {
    $0.a = A(a: 1)
}
// Parent scope can be explicitly provided.
// So in `abScope` both `a` and `b` properties are overridden.
let abScope = KvEnvironmentScope(parent: aScope) {
    $0.b = B(b: "custom")
}
```

Below is an example of a way to temporary override global scope:
```swift
let c = C()

// Here dependencies are resolved in the global scope.
print(c)

// In block below current scope is changed to `abScope`.
abScope {
    // Here dependencies are resolved in `abScope`.
    print(c)
}
```

There are several ways to provide explicit scope to dependency references:
- in attribute declaration `@Environment(\.a, scope: someScope) private var a`;
- when a scope is instantiated, all it\'s direct properties refer to the scope;
- via projected value `$a.scope = someScope`;
- it possible to change all scope references of arbitrary instances via `replace(in:options:)` method of `KvEnvironmentScope`.

### Cyclic References

```swift
struct E {
    let id: String

    @KvEnvironment(\.f) var f
}

struct F {
    let id: String

    @KvEnvironment(\.e) var e
}

extension KvEnvironmentScope {
    #kvEnvironment {
        var e: E
        var f: F
    }
}

struct G: CustomStringConvertible {
    @KvEnvironment(\.e) private var e
    @KvEnvironment(\.f) private var f
}

// Populating global scope with required values.
KvEnvironmentScope.global {
    $0.e = E(id: "e1")
    $0.f = F(id: "f1")
}

let g = G()
// e: "e1", f: "f1", e.f: "f1", f.e: "e1".
print(g)
```


## Authors

- Svyatoslav Popov ([@sdpopov-keyvariable](https://github.com/sdpopov-keyvariable), [info@keyvar.com](mailto:info@keyvar.com)).
