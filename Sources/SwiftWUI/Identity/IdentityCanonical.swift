/// ObjectIdentifier → fully-qualified type name (spec §7 / D7). Populated by
/// resolve<T> at every component boundary. ObjectIdentifier is process-local;
/// the snapshot needs a name that is identical in the native builder and the
/// wasm client of the same source — String(reflecting:) is exactly that.
/// NEVER use hashValue anywhere in this file (seed-randomized per process).
enum _TypeNameRegistry {
    private(set) static var names: [ObjectIdentifier: String] = [:]
    static func register(_ type: Any.Type, name: String? = nil) {
        let oid = ObjectIdentifier(type)
        if let name, !name.isEmpty {
            names[oid] = name
        } else if names[oid] == nil {
            names[oid] = String(reflecting: type)
        }
    }
}

// (No replacingOccurrences — that's Foundation, and the core is Foundation-free.)
private func escapeSegmentPayload(_ s: String) -> String {
    guard s.contains("%") || s.contains("/") else { return s }
    var out = ""
    out.reserveCapacity(s.count)
    for ch in s {
        switch ch {
        case "%": out += "%25"
        case "/": out += "%2F"
        default:  out.append(ch)
        }
    }
    return out
}

extension NodeIdentity {
    /// Canonical cross-process form (spec D7): "c0/tTodoMVC.AboutPage/c0/b1".
    /// The exact grammar is a compatibility surface between an SSG build and
    /// the wasm client built from the same source — pinned by a golden test.
    public var _canonicalString: String? {
        var parts: [String] = []
        parts.reserveCapacity(segments.count)
        for seg in segments {
            switch seg {
            case .child(let n):   parts.append("c\(n)")
            case .branch(let b):  parts.append(b ? "b1" : "b0")
            case .keyed(let k):
                // String(describing:) is type-erasing: NodeKey(5) and NodeKey("5") both → "k5".
                // Fine for homogeneous sibling keys (the practical case); heterogeneous
                // same-description keys at one position would collide.
                parts.append("k" + escapeSegmentPayload(String(describing: k.base)))
            case .type(let oid):
                guard let name = _TypeNameRegistry.names[oid] else { return nil }
                parts.append("t" + escapeSegmentPayload(name))
            }
        }
        return parts.joined(separator: "/")
    }
}
