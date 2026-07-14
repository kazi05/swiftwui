/// Deduplicating, monotonic rule store (spec §7, D9). Rules are never removed;
/// growth is bounded by the number of DISTINCT rules the app produces.
/// ponytail: no sweep — add one when profiling shows unbounded distinct rules.
@MainActor
public final class StyleRegistry {
    struct Entry {
        let media: String        // "" for no condition — sorts before any @media
        let container: String     // "" for no @container condition
        let text: String         // full rule text WITHOUT media wrapper
        let hash: UInt64
    }
    private var byHash: [UInt64: Entry] = [:]
    private(set) var version = 0

    public init() {}

    static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }
    static func className(_ hash: UInt64) -> String {
        "swui-" + String(hash, radix: 36)
    }

    /// Serializes declarations, dropping any rule-unsafe value (spec §12 sink).
    static func body(_ declarations: [StyleDeclaration]) -> String {
        declarations.compactMap { d in
            guard CSSSanitize.isSafeValue(d.value) else {
                assertionFailure("unsafe CSS value dropped: \(d.property): \(d.value)")
                return nil
            }
            return "\(d.property): \(d.value)"
        }.joined(separator: "; ")
    }

    private func insert(media: String, container: String, text: String, seed: String) -> UInt64 {
        let hash = Self.fnv1a(seed)
        if byHash[hash] == nil {
            byHash[hash] = Entry(media: media, container: container, text: text, hash: hash)
            version += 1
        }
        return hash
    }

    /// Element-attached rule (.hover/.media modifiers, wrapper rules):
    /// returns the generated class name; the rule targets exactly that class.
    func registerAnonymous(pseudo: String?, media: String?, container: String? = nil,
                           declarations: [StyleDeclaration]) -> String {
        let body = Self.body(declarations)
        let seed = "anon|\(pseudo ?? "")|\(media ?? "")|\(container ?? "")|\(body)"
        let hash = Self.fnv1a(seed)
        let cls = Self.className(hash)
        guard !declarations.isEmpty else { return cls }   // nothing to register — no useless `{ }` rule
        let selector = "." + cls + (pseudo ?? "")
        _ = insert(media: media ?? "", container: container ?? "", text: "\(selector) { \(body) }", seed: seed)
        return cls
    }

    /// Styled/global rule: explicit selector base (".field" / "#submit" / "input"),
    /// optional scope marker class appended (spec §8).
    func registerSelector(base: String, scope: String?, pseudo: String?, media: String?,
                          container: String? = nil, declarations: [StyleDeclaration]) {
        let body = Self.body(declarations)
        let selector = base + (scope.map { "." + $0 } ?? "") + (pseudo ?? "")
        let seed = "sel|\(selector)|\(media ?? "")|\(container ?? "")|\(body)"
        _ = insert(media: media ?? "", container: container ?? "", text: "\(selector) { \(body) }", seed: seed)
    }

    /// Pre-serialized block (themes, Task 9). Caller guarantees safety of the
    /// text (built from validated tokens + CSSValueConvertible values only).
    func registerRaw(_ text: String) {
        _ = insert(media: "", container: "", text: text, seed: "raw|" + text)
    }

    /// Canonical order: (media, container, hash) — deterministic regardless of which
    /// pass registered first (spec §7: scoped ≡ full byte-identical text).
    public var text: String {
        let sorted = byHash.values.sorted {
            ($0.media, $0.container, $0.hash) < ($1.media, $1.container, $1.hash)
        }
        return sorted.map { e in
            if !e.container.isEmpty { return "@container \(e.container) { \(e.text) }" }
            if !e.media.isEmpty { return "@media \(e.media) { \(e.text) }" }
            return e.text
        }.joined(separator: "\n")
    }
}
