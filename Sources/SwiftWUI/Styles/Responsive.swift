/// A per-breakpoint style value: an unconditional `base` plus mobile-first
/// overrides. Overrides emit non-overlapping [bp, nextBp) media ranges so the
/// cascade does not depend on stylesheet source order.
public struct Responsive<Value> {
    public var base: Value
    public var overrides: [(Breakpoint, Value)]   // ascending by breakpoint
    public init(base: Value, overrides: [(Breakpoint, Value)]) {
        self.base = base
        self.overrides = overrides.sorted { $0.0 < $1.0 }
    }
}

public func responsive<V>(_ base: V, sm: V? = nil, md: V? = nil,
                          lg: V? = nil, xl: V? = nil) -> Responsive<V> {
    var o: [(Breakpoint, V)] = []
    if let sm { o.append((.sm, sm)) }
    if let md { o.append((.md, md)) }
    if let lg { o.append((.lg, lg)) }
    if let xl { o.append((.xl, xl)) }
    return Responsive(base: base, overrides: o)
}
