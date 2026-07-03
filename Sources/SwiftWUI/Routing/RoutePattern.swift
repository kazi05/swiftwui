/// URL helpers (spec §4). No Foundation — percent-decoding is hand-rolled.
enum RouteURL {
    /// Guarantees a leading "/", strips trailing "/" (root untouched): "/x/" → "/x".
    static func normalizePath(_ path: String) -> String {
        var p = path.hasPrefix("/") ? path : "/" + path
        var n = p.count                                   // computed once — O(n) total
        while n > 1 && p.hasSuffix("/") { p.removeLast(); n -= 1 }
        return p
    }

    /// "https://…", "mailto:…", "//host/…" — anything that leaves the app.
    static func isExternal(_ url: String) -> Bool {
        if url.hasPrefix("//") { return true }
        for ch in url {
            if ch == ":" { return true }
            if ch == "/" || ch == "?" || ch == "#" { return false }
        }
        return false
    }

    /// Path split on "/", empty segments dropped ("//" tolerated).
    static func pathSegments(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    /// "/a/b?x=1&y=2" → (path: "/a/b", query: ["x": "1", "y": "2"], search: "x=1&y=2").
    /// A "#fragment" suffix is dropped (never sent to servers, never routed on).
    static func split(_ url: String) -> (path: String, query: [String: String], search: String) {
        var u = url
        if let hash = u.firstIndex(of: "#") { u = String(u[..<hash]) }
        guard let q = u.firstIndex(of: "?") else { return (u, [:], "") }
        let search = String(u[u.index(after: q)...])
        return (String(u[..<q]), parseQuery(search), search)
    }

    /// Pairs split on "&", each on the FIRST "=", both sides percent-decoded.
    /// "+" is NOT treated as space (that's form encoding, not URLs).
    static func parseQuery(_ search: String) -> [String: String] {
        var out: [String: String] = [:]
        for pair in search.split(separator: "&") {
            guard !pair.isEmpty else { continue }
            if let eq = pair.firstIndex(of: "=") {
                out[percentDecode(String(pair[..<eq]))] =
                    percentDecode(String(pair[pair.index(after: eq)...]))
            } else {
                out[percentDecode(String(pair))] = ""
            }
        }
        return out
    }

    /// %XX UTF-8 decode. An invalid escape leaves the WHOLE input unchanged
    /// (spec §4/§11: never trap, never half-decode).
    /// A well-formed escape of invalid UTF-8 (e.g. "%FF") decodes to U+FFFD (browser-consistent).
    static func percentDecode(_ s: String) -> String {
        guard s.contains("%") else { return s }
        func hex(_ b: UInt8) -> UInt8? {
            switch b {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): return b - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): return b - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): return b - UInt8(ascii: "A") + 10
            default: return nil
            }
        }
        let u = Array(s.utf8)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(u.count)
        var i = 0
        while i < u.count {
            if u[i] == UInt8(ascii: "%") {
                guard i + 2 < u.count, let hi = hex(u[i + 1]), let lo = hex(u[i + 2]) else { return s }
                bytes.append(hi << 4 | lo); i += 3
            } else {
                bytes.append(u[i]); i += 1
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Parsed route pattern (spec §4): literal | :param | * (catch-all, last only).
struct RoutePattern: Equatable {
    enum Segment: Equatable {
        case literal(String)
        case param(String)
        case catchAll
    }
    let raw: String
    let segments: [Segment]

    init(_ raw: String) {
        self.raw = raw
        let parts = RouteURL.pathSegments(RouteURL.normalizePath(raw))
        var segs: [Segment] = []
        for (i, part) in parts.enumerated() {
            if part == "*" {
                assert(i == parts.count - 1, "RoutePattern: '*' must be the last segment in '\(raw)'")
                segs.append(.catchAll)
            } else if part.hasPrefix(":") {
                let name = String(part.dropFirst())
                assert(!name.isEmpty, "RoutePattern: empty ':' parameter name in '\(raw)'")
                segs.append(.param(name.isEmpty ? "_" : name))
            } else {
                segs.append(.literal(part))
            }
        }
        if let i = segs.firstIndex(of: .catchAll), i < segs.count - 1 {
            segs = Array(segs[...i])          // release degrade: '*' swallows the tail (documented)
        }
        self.segments = segs
    }

    /// Captured params (percent-decoded), or nil when the path doesn't match.
    /// A catch-all's tail lands under key "*". Matching is case-sensitive.
    func match(_ path: String) -> [String: String]? {
        let parts = RouteURL.pathSegments(RouteURL.normalizePath(path))
            .map(RouteURL.percentDecode)
        var params: [String: String] = [:]
        var i = 0
        for seg in segments {
            switch seg {
            case .catchAll:
                params["*"] = parts[i...].joined(separator: "/")
                return params
            case .literal(let lit):
                guard i < parts.count, parts[i] == lit else { return nil }
            case .param(let name):
                guard i < parts.count else { return nil }
                params[name] = parts[i]
            }
            i += 1
        }
        return i == parts.count ? params : nil
    }
}
